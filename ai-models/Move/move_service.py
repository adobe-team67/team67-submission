from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import torch
import os
import psutil
import time

import base64
import numpy as np
from PIL import Image
import cv2
import io
import base64
from DragonDiffusion.src.demo.model import DragonModels
from DragonDiffusion.move import move
import logging
from monitoring import MetricsRecorder

logging.basicConfig(level=logging.INFO, filename='/app/logs/move.log')
logger = logging.getLogger(__name__)

app = FastAPI(title="Move3 Service")

move_model = None
current_draw_box_path = None


def file_to_base64(file_path):
    print("in function: ", file_path)
    with open(file_path, "rb") as f:
        return base64.b64encode(f.read()).decode()


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


def save_temp_image_from_base64(image_b64: str, prefix: str = "img") -> str:
    try:
        image_bytes = base64.b64decode(image_b64)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid base64 image: {e}")

    os.makedirs("data/tmp", exist_ok=True)
    ts = int(time.time() * 1000)
    temp_path = os.path.join("data/tmp", f"{prefix}_{ts}.png")

    try:
        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        img.save(temp_path)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to decode/save image: {e}")

    return temp_path


class Move3Request(BaseModel):
    image: str 
    mask: str
    x_in: int
    y_in: int
    x_f: int
    y_f: int


@app.on_event("startup")
async def load_models():
    global move_model

    os.makedirs("output", exist_ok=True)
    os.makedirs("data/erase", exist_ok=True)
    os.makedirs("data/masks", exist_ok=True)
    os.makedirs("data/bb", exist_ok=True)
    os.makedirs("data/inpainted", exist_ok=True)
    os.makedirs("data/tmp", exist_ok=True)

    try:
        pretrained_model_path = "runwayml/stable-diffusion-v1-5"
        move_model = DragonModels(pretrained_model_path=pretrained_model_path)
        
        if move_model is not None:
            logger.info("Move model loaded successfully.")
        else:
            logger.error("Failed to load Move model.")
            raise RuntimeError("Failed to load DragonDiffusion models")
    except Exception as e:
        print(f"Warning: failed to load DragonDiffusion models for move: {e}")
        logger.error(f"Failed to load Move model: {e}")
        move_model = None


@app.post("/move3")
async def move3(request: Move3Request):
    global move_model
    recorder = MetricsRecorder(interval=1.0)
    recorder.start()
    if move_model is None:
        logger.error("Move model not loaded")
        raise HTTPException(status_code=503, detail="DragonDiffusion move model not loaded")

    temp_img_path = None
    temp_mask_path = None

    try:
        temp_img_path = save_temp_image_from_base64(request.image, prefix="move3")
        temp_mask_path = save_temp_image_from_base64(request.mask, prefix="movemask")

        logger.info("Saved image and mask to temp folder")

        img = cv2.imread(temp_img_path)
        mask = cv2.imread(temp_mask_path)

        logger.info("Passing for inference...")
        result = move(img=img, mask=mask, x_s=request.x_in, y_s=request.y_in, x_e=request.x_f, y_e=request.y_f, model=move_model)
        logger.info("Inference completed.")
        cv2.cvtColor(result, cv2.COLOR_BGR2RGB)
        if isinstance(result, np.ndarray):
            result_img = Image.fromarray(result)
        elif isinstance(result, torch.Tensor):
            result_img = Image.fromarray(result.cpu().numpy())
        else:
            result_img = result
        buffer = io.BytesIO()
        result_img.save(buffer, format="PNG")
        buffer.seek(0)
        result_base64 = base64.b64encode(buffer.read()).decode()
        log_system_usage("After move3")
        logger.info("Move completed successfully.")
        recorder.stop()
        metrics = recorder.get_metrics()
        return {
            "message": "Move operation completed successfully",
            "result_image": result_base64,
            "metrics": metrics
        }
    except Exception as e:
        logger.error(f"Move operation failed: {e}")
        raise HTTPException(status_code=500, detail=f"Move operation failed: {str(e)}")
    finally:
        if temp_img_path and os.path.exists(temp_img_path):
            os.remove(temp_img_path)
            logger.info("Temporary folder files removed.")


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "move_loaded": move_model is not None
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
