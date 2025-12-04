from fastapi import FastAPI, HTTPException, File, Form
from pydantic import BaseModel
import os
import time
from typing import Optional
import base64
import torch
from diffusers import AutoPipelineForInpainting
from inpainting.inpaint_sd import run_inpaint
import uvicorn
from Monitoring import MetricsRecorder
import logging

logging.basicConfig(level=logging.INFO, filename='/app/logs/inpainting_service.log')
logger = logging.getLogger(__name__)


app = FastAPI(title="Inpaint Service")
def save_base64_file(base64_str: str, output_path: str):
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    file_bytes = base64.b64decode(base64_str)
    with open(output_path, "wb") as f:
        f.write(file_bytes)

    return output_path

def encode_image_to_base64(image_path):
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"Image not found at path: {image_path}")
    
    with open(image_path, "rb") as image_file:
        encoded_string = base64.b64encode(image_file.read()).decode('utf-8')
    return encoded_string



class InpaintRequest(BaseModel):
    img_base64: Optional[str] = None
    mask_base64: Optional[str] = None
    prompt: Optional[str] = None


device = None
pipeline = None
generator = None

@app.on_event("startup")
async def load_models():
    global device, pipeline, generator
    device = "cuda" if torch.cuda.is_available() else "cpu"
    dtype = torch.float16 if device == "cuda" else torch.float32
    model_id="kandinsky-community/kandinsky-2-2-decoder-inpaint"
    print(f"Running on device: {device}, dtype: {dtype}")
    pipeline = AutoPipelineForInpainting.from_pretrained(
        model_id,
        torch_dtype=torch.float16 if device == "cuda" else torch.float32,
        use_safetensors=True
    )
    seed=92
    generator = torch.Generator(device=device).manual_seed(seed)

@app.post("/inpaint")
async def inpaint(img_base64: str = Form(...), mask_base64: str = Form(...), prompt: str = Form(None)):
    recorder = MetricsRecorder(interval=1.0)
    recorder.start()
    image_path = "/app/data/input/{}_input.png".format(int(time.time()*1000))
    mask_path = "/app/data/input/{}_mask.png".format(int(time.time()*1000))
    save_base64_file(img_base64, image_path)
    save_base64_file(mask_base64, mask_path)
    global device, pipeline, generator
    try:
        output_image_path, grid_image_path = run_inpaint(
            image_path=image_path,
            mask_path=mask_path,
            prompt=prompt if prompt else "",
            pipeline=pipeline,
            generator=generator,
            device=device
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    output_image_b64 = encode_image_to_base64(output_image_path)
    recorder.stop()
    metrics = recorder.get_metrics()
    return {
        "image": output_image_b64,
        "metrics": metrics
    }

uvicorn.run(app, host="0.0.0.0", port=8002)