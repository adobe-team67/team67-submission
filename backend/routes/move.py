# app/routes/users.py
import logging
from fastapi import APIRouter
from backend.logger import setup_logger
import time
import base64
import os
from backend.models.models import MoveRequest, MoveResponse
from backend.utils.combinemasks import combine_bitmasks
from backend.utils.savebas64 import save_base64_file
from backend.utils.encodebase64 import encode_image_to_base64
from fastapi import HTTPException
import re
import httpx
from PIL import Image
import numpy as np
from dotenv import load_dotenv
load_dotenv()

logger = setup_logger("move")

router = APIRouter(
    prefix="",
    tags=["move"],
)

ORIGINAL_IMAGE_DIR = os.getenv("ORIGINAL_IMAGE_DIR", "data/original_from_frontend")
MASK_DIR = os.getenv("MASK_DIR", "data/masks_for_frontend")
OUTPUT_MOVE_DIR = os.getenv("OUTPUT_MOVE_DIR", "output/movedimages")
DETECTION_SEGMENTATION_URL = os.getenv("DETECTION_SEGMENTATION_URL", "http://10.36.16.15:8001")
DETECTION_SEGMENTATION_URL="http://10.36.16.96:8001"




@router.post("/move")
async def move_selection(request: MoveRequest):
    """Move selected object to new position"""
    current_coord_x = int(request.startx)
    current_coord_y = int(request.starty)
    manual_masks = request.manual_masks
    start_time = time.time()
    logger.info("="*60)
    logger.info("MOVE REQUEST RECEIVED")
    logger.info(f"Target position: ({request.endx}, {request.endy})")
    logger.info(f"Prompt: {request.prompt}")
    end_x = int(request.endx)
    end_y = int(request.endy)
    
    try:
        current_image_name = request.image_name
        current_original_image_path = f"{ORIGINAL_IMAGE_DIR}/{current_image_name}"
        mask_paths = []
        num = re.search(r'_(\d+)_', current_image_name).group(1)
        current_timestamp_mask = num
        if manual_masks is not None:

            mask_array = manual_masks[0]
            mask_array = np.array(mask_array, dtype=np.uint8)
            mask_image = Image.fromarray(mask_array, mode="L")
            mask_name = f"mask_{current_timestamp_mask}_manual_set.png"
            mask_path = os.path.join(MASK_DIR, mask_name)
            mask_image.save(mask_path)
            current_mask_path = f"{MASK_DIR}/mask_{current_timestamp_mask}_manual_set.png"

            logger.info(f"Using original image: {current_original_image_path}")

            prompt = "remove the object from the image"
            logger.info(f"Erase prompt: {prompt}")
        else:
            for i in request.masks_ids:
                current_mask_path = f"{MASK_DIR}/mask_{current_timestamp_mask}_{i}_set.png"
                mask_paths.append(current_mask_path)
            logger.info(f"Using original image: {current_original_image_path}")

            prompt = "remove the object from the image"
            logger.info(f"Erase prompt: {prompt}")
            combined_mask_path = combine_bitmasks(mask_paths, output_path=f"{MASK_DIR}/combined_mask_{current_timestamp_mask}.png")
            current_mask_path = combined_mask_path
        logger.info(f"Using original image: {current_original_image_path}")
        logger.info(f"Using mask: {current_mask_path}")
        
        logger.info(f"From: ({current_coord_x}, {current_coord_y}) To: ({request.endx}, {request.endy})")
        

        with open(current_original_image_path, "rb") as f:
            image_b64 = base64.b64encode(f.read()).decode("utf-8")
            mask_64 = encode_image_to_base64(current_mask_path)
            logger.info(f"Calling generative microservice at {DETECTION_SEGMENTATION_URL}/move3")
            move_start = time.time()
            base64_image = None
            async with httpx.AsyncClient(timeout=180.0) as client:
                response = await client.post(
                    f"{DETECTION_SEGMENTATION_URL}/move3",
                    json={
                        "image": image_b64,
                        "mask": mask_64,
                        "x_in": current_coord_x,
                        "y_in": current_coord_y,
                        "x_f": end_x,
                        "y_f": end_y
                    }
                )
            
            if response.status_code != 200:
                logger.error("Move service returned error", exc_info=True)
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"Move service error: {response.text}"
                )
            
            result = response.json()
            base64_image = result["result_image"]
        os.makedirs(OUTPUT_MOVE_DIR, exist_ok=True)
        save_base64_file(base64_image, f"{OUTPUT_MOVE_DIR}/moved_{int(time.time()*1000)}.png")
        metrics=result["metrics"]
        logger.info(f"Move operation completed in {time.time() - move_start:.3f}s")
        
        total_time = time.time() - start_time
        logger.info(f"✓ MOVE COMPLETED IN {total_time:.3f}s")
        logger.info("="*60)
        
        return MoveResponse(
            image=base64_image,
            message=f"Successfully moved",
            metrics=metrics
        )
        
    except Exception as e:
        logger.error(f"✗ MOVE FAILED after {time.time() - start_time:.3f}s: {str(e)}", exc_info=True)
        logger.error(f"Error processing move: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error processing move: {str(e)}")