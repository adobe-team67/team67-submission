# app/routes/users.py
import logging
from fastapi import APIRouter
from backend.logger import setup_logger
import time
import base64
import io
import os
from PIL import Image
from backend.models.models import SetImageRequest
from fastapi import HTTPException
from dotenv import load_dotenv
load_dotenv()
logger = setup_logger("set-image")

router = APIRouter(
    prefix="",
    tags=["set-image"],
)



@router.post("/set-image")
async def set_image(request: SetImageRequest):
    """Set current image from frontend (without any selection)"""
    logger.info("Set image request received")
    try:
        image_data = base64.b64decode(request.image)
        image = Image.open(io.BytesIO(image_data)).convert("RGB")
        
        # Save image locally
        original_dir = os.getenv("ORIGINAL_IMAGE_DIR", "data/original_from_frontend")
        os.makedirs(original_dir, exist_ok=True)
        
        timestamp = int(time.time() * 1000)
        img_name = f"image_{timestamp}_set.png"
        img_path = os.path.join(original_dir, img_name)
        image.save(img_path)
        
        logger.info(f"Image set successfully: {img_path}")
        return {
            "message": "Image set successfully.",
            "image_path": img_path,
            "image_name": img_name,
            "width": image.width,
            "height": image.height
        }
    except Exception as e:
        logger.error(f"Error setting image: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error setting image: {str(e)}")