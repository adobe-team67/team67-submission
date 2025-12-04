# app/routes/users.py
import logging
from fastapi import APIRouter
from backend.logger import setup_logger
import os
from PIL import Image
from backend.models.models import SetMasksRequest
from fastapi import HTTPException
import re
import numpy as np
from dotenv import load_dotenv
load_dotenv()

logger = setup_logger("set-masks")

router = APIRouter(
    prefix="",
    tags=["set-masks"],
)




@router.post("/set-masks")
async def set_masks(request: SetMasksRequest):
    """Set current masks from frontend (without refine-selection)"""
    logger.info("Set masks request received")
    try:
        current_bitmasks = []
        current_masks = []
        num = re.search(r'_(\d+)_', request.image_name).group(1)
        timestamp = num
        mask_dir = os.getenv("MASK_DIR", "data/masks_for_frontend")
        os.makedirs(mask_dir, exist_ok=True)
        for idx, bitmask in enumerate(request.masks):
            bitmask_array = np.array(bitmask, dtype=np.uint8)
            if bitmask_array.max() <= 1:
                mask_array = bitmask_array * 255
            else:
                mask_array = bitmask_array
            mask_image = Image.fromarray(mask_array, mode="L")
            mask_name = f"mask_{timestamp}_{idx}_set.png"
            mask_path = os.path.join(mask_dir, mask_name)
            mask_image.save(mask_path)
            current_masks.append(mask_name)
            current_bitmasks.append(bitmask)
            logger.info(f"Saved mask: {mask_path}")
        
        logger.info(f"{len(current_masks)} masks set successfully.")
        return {
            "message": f"{len(current_masks)} masks set successfully.",
            "masks": current_masks
        }
    except Exception as e:
        logger.error(f"Error setting masks: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error setting masks: {str(e)}")