from fastapi import FastAPI, HTTPException, Form
from pydantic import BaseModel
from typing import Optional
import base64
import io
from io import BytesIO
import logging
from monitoring import MetricsRecorder
import torch
import PIL.Image as Image
from diffusers import FluxKontextPipeline, GGUFQuantizationConfig
from diffusers.hooks import apply_group_offloading
import uvicorn
import logging
import httpx
from diffusers import BitsAndBytesConfig as FluxTransformer2DModel


logging.basicConfig(level=logging.INFO, filename='/app/style.log')
logger = logging.getLogger(__name__)


app = FastAPI(title="Flux with mask Service")


def save_base64_image(b64_str: str, filename: str = "imgb.png"):
    img_bytes = base64.b64decode(b64_str)
    img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
    img.save(filename, format="PNG")
    print(f"Saved image → {filename}")


class FluxRequest(BaseModel):
    img_base64: Optional[str] = None
    mask_base64: Optional[str] = None
    prompt: Optional[str] = None

class imgtoimgRequest(BaseModel):
    img: str
    prompt: str = ""

class TwoImagesRequest(BaseModel):
    img_a: str   # base64 string
    img_b: str   # base64 string


pipe = None
processor = None
model = None


@app.on_event("startup")
async def load_models():
    logger.info("Loading model for stylising...")
    global pipe, model, processor
    try:
        ckpt_path = ("flux1-kontext-dev-Q8_0.gguf")
        transformer = FluxTransformer2DModel.from_single_file(
            ckpt_path,
            quantization_config=GGUFQuantizationConfig(compute_dtype=torch.bfloat16),
            torch_dtype=torch.bfloat16,
            config="black-forest-labs/FLUX.1-Kontext-dev",
            subfolder="transformer",
        ) 
        pipe = FluxKontextPipeline.from_pretrained(
            "black-forest-labs/FLUX.1-Kontext-dev", torch_dtype=torch.bfloat16, transformer=transformer
        )
        pipe.text_encoder.to("cuda")
        pipe.text_encoder_2.to("cuda")
        # pipe.vae.to("cuda")
        apply_group_offloading(pipe.transformer,offload_type="leaf_level",offload_device=torch.device("cpu"),onload_device=torch.device("cuda"),use_stream=True,)
        apply_group_offloading(pipe.vae,offload_type="leaf_level",offload_device=torch.device("cpu"),onload_device=torch.device("cuda"),use_stream=True,)
    except Exception as e:
        raise RuntimeError(f"Failed to load flux model: {e}") 

@app.post("/imgtoimg")
async def img_to_img(request: imgtoimgRequest):
    recorder = MetricsRecorder(interval=1.0)
    recorder.start()
    logger.info("Received img to img request.")
    img_data = base64.b64decode(request.img)
    img = Image.open(io.BytesIO(img_data)).convert("RGB")
    prompt = request.prompt
    seed = 42
    logger.info("Passing to model for stylising.")
    result_image = pipe(
        image=img,
        prompt=prompt,
        output_type="pil",
        num_inference_steps=10,
        generator=torch.Generator("cpu").manual_seed(seed)
    ).images[0]
    logger.info("Stylising completed successfully.")
    buffer = BytesIO()
    result_image.save(buffer, format="PNG") 
    buffer.seek(0)
    img_bytes = buffer.getvalue()
    img_b64 = base64.b64encode(img_bytes).decode("utf-8")
    logger.info("Saving stylised image.")
    recorder.stop()
    metrics = recorder.get_metrics()
    return {
        "image": img_b64,
        "metrics": metrics
    }

uvicorn.run(app, host="0.0.0.0", port=8006)