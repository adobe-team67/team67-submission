import io
import os
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.responses import StreamingResponse
import torch
from objectclear.pipelines import ObjectClearPipeline
from objectclear.utils import resize_by_short_side
from PIL import Image
import logging
import psutil
from monitoring import MetricsRecorder
logging.basicConfig(level=logging.INFO, filename='/app/logs/erase.log')
logger = logging.getLogger(__name__)

app = FastAPI(title="ObjectClear API", version="1.0.0")

pipe = None
device = None
generator = None


import torch
import psutil
import os

def log_system_usage(tag: str = ""):
    process = psutil.Process(os.getpid())
    
    ram_bytes = process.memory_info().rss 
    ram_gb = ram_bytes / (1024 ** 3)
    
    msg = f"[{tag}] RAM (CPU): {ram_gb:.2f} GB"

    if torch.cuda.is_available():
        vram_allocated = torch.cuda.memory_allocated() / (1024 ** 3)
        vram_reserved = torch.cuda.memory_reserved() / (1024 ** 3)
        msg += f" | VRAM (GPU): {vram_allocated:.2f} GB (Reserved: {vram_reserved:.2f} GB)"
    else:
        msg += " | VRAM: N/A (Running on CPU)"

    logger and logger.info(msg) if logger else print(msg)

@app.on_event("startup")
async def load_model():
    """Load the ObjectClear model on startup"""
    
    global pipe, device, generator
    
    logger.info("Starting up ObjectClear service...")
    logger.info("Loading ObjectClear model...")
    
    try:
        device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        logger.info(f"Using device: {device}")
        
        use_fp16 = os.getenv("USE_FP16", "true").lower() == "true"
        seed = int(os.getenv("SEED", "42"))
        use_agf = os.getenv("USE_AGF", "true").lower() == "true"
        cache_dir = os.getenv("CACHE_DIR", None)
        model_dtype = torch.float16 if use_fp16 else torch.float32
        variant = 'fp16' if use_fp16 else None
        
        generator = torch.Generator(device=device).manual_seed(seed)
        
        logger.info(f"Loading model with dtype={model_dtype}...")

        pipe = ObjectClearPipeline.from_pretrained_with_custom_modules(
            "jixin0101/ObjectClear",
            torch_dtype=model_dtype,
            apply_attention_guided_fusion=use_agf,
            cache_dir=cache_dir,
            variant=variant,
        )
        
        pipe.to(device, dtype=model_dtype)
        
        if hasattr(pipe, 'safety_checker') and pipe.safety_checker is not None:
            pipe.safety_checker = None
            
        logger.info("Model loaded successfully!")
        log_system_usage("After model load")
        
    except Exception as e:
        logger.error(f"Failed to load model: {str(e)}")
        raise

@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "running",
        "model_loaded": pipe is not None,
        "device": str(device) if device else None
    }

@app.get("/health")
async def health():
    """Detailed health check"""
    if pipe is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    return {"status": "healthy", "device": str(device)}

@app.post("/erase")
async def erase_object(
    image: UploadFile = File(..., description="Input image file"),
    mask: UploadFile = File(..., description="Mask image file"),
    steps: int = Form(20, description="Number of diffusion inference steps"),
    guidance_scale: float = Form(2.5, description="CFG guidance scale"),
    resize_short_side: int = Form(512, description="Resize shorter side to this value")
):
    recorder = MetricsRecorder(interval=1.0)
    recorder.start()
    if pipe is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    
    try:
        logger.info(f"Processing request - steps: {steps}, guidance_scale: {guidance_scale}")
        
        image_bytes = await image.read()
        mask_bytes = await mask.read()
        
        input_image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        input_mask = Image.open(io.BytesIO(mask_bytes)).convert("L")
        
        original_size = input_image.size
        logger.info(f"Original image size: {original_size}")
        
        resized_image = resize_by_short_side(input_image, resize_short_side, resample=Image.BICUBIC)
        resized_mask = resize_by_short_side(input_mask, resize_short_side, resample=Image.NEAREST)
        
        w, h = resized_image.size
        logger.info(f"Resized to: {w}x{h}, passing to model...")
        
        result = pipe(
            prompt="remove the instance of object",
            image=resized_image,
            mask_image=resized_mask,
            generator=generator,
            num_inference_steps=steps,
            guidance_scale=guidance_scale,
            height=h,
            width=w,
            return_attn_map=False,
        )
        
        output_image = result.images[0]
        output_image = output_image.resize(original_size, resample=Image.BICUBIC)
        
        img_byte_arr = io.BytesIO()
        output_image.save(img_byte_arr, format='PNG')
        img_byte_arr.seek(0)
        
        logger.info("Processing completed successfully")
        log_system_usage("After erase inference")
        recorder.stop()
        return StreamingResponse(
            img_byte_arr,
            media_type="image/png",
            headers={"Content-Disposition": "attachment; filename=result.png"}
        )
        
    except Exception as e:
        logger.error(f"Error processing image: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error processing image: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8005)
