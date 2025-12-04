# app/routes/users.py
import logging
from fastapi import APIRouter
from backend.logger import setup_logger
import time
import base64
import io
import os
from PIL import Image
from backend.models.models import EraseRequest, EraseResponse
from fastapi import HTTPException
import re
import httpx
from backend.utils.combinemasks import combine_bitmasks
import numpy as np
from dotenv import load_dotenv
load_dotenv()


logger = setup_logger("erase")

router = APIRouter(
    prefix="",
    tags=["erase"],
)

ORIGINAL_IMAGE_DIR = os.getenv("ORIGINAL_IMAGE_DIR", "data/original_from_frontend")
MASK_DIR = os.getenv("MASK_DIR", "data/masks_for_frontend")
ERASE_URL = os.getenv("ERASE_URL", "http://10.36.16.96:8005")
ERASE_OUTPUT_PATH = os.getenv("ERASE_OUTPUT_PATH")

@router.post("/erase")
async def erase_selection(request: EraseRequest):
    """Erase selected object using generative microservice"""
    manual_masks = request.manual_masks
    start_time = time.time()
    logger.info("="*60)
    logger.info("ERASE REQUEST RECEIVED")
    try:
        current_image_name = request.image_name
        current_original_image_path = f"{ORIGINAL_IMAGE_DIR}/{current_image_name}"
        mask_paths = []
        num = re.search(r'_(\d+)_', current_image_name).group(1)
        current_timestamp_mask = num
        if manual_masks is not None:
            logger.info("Using manual masks for erasing")
            mask_array = manual_masks[0]
            mask_array = np.array(mask_array, dtype=np.uint8)
            mask_image = Image.fromarray(mask_array, mode="L")
            mask_name = f"mask_{current_timestamp_mask}_manual_set.png"
            mask_path = os.path.join(MASK_DIR, mask_name)
            mask_image.save(mask_path)
            current_mask_path = f"{MASK_DIR}/mask_{current_timestamp_mask}_manual_set.png"
            logger.info(f"Using original image: {current_original_image_path}")
            logger.info(f"Using mask: {current_mask_path}")
            prompt = "remove the object from the image"
            logger.info(f"Erase prompt: {prompt}")
        else:
            logger.info("Using predefined masks for erasing")
            logger.info(manual_masks==None)
            for i in request.masks_ids:
                current_mask_path = f"{MASK_DIR}/mask_{current_timestamp_mask}_{i}_set.png"
                mask_paths.append(current_mask_path)
            logger.info(f"Using original image: {current_original_image_path}")
            logger.info(f"Using mask: {current_mask_path}")
            prompt = "remove the object from the image"
            logger.info(f"Erase prompt: {prompt}")
            combined_mask_path = combine_bitmasks(mask_paths, output_path=f"{MASK_DIR}/combined_mask_{current_timestamp_mask}.png")
            current_mask_path = combined_mask_path
        params = {
            "steps": 20,
            "guidance_scale": 2.5,
            "resize_short_side": 512
        }
        
        erase_start = time.time()
        with open(current_mask_path, "rb") as mask, open(current_original_image_path, "rb") as img:
            files = {
                "image": img,
                "mask": mask,
            }
            
            async with httpx.AsyncClient(timeout=120.0) as client:
                response = await client.post(
                    f"{ERASE_URL}/erase",
                    files=files,
                    data=params
                )
                
                if response.status_code != 200:
                    raise HTTPException(
                        status_code=response.status_code,
                        detail=f"Erase service error: {response.text}"
                    )
                
                # Extract filename from Content-Disposition header
                content_disposition = response.headers.get('Content-Disposition')
        
        if content_disposition:

            filename_match = re.search(r'filename=["\']?([^;\s"]+)', content_disposition)
            
            if filename_match:
                filename = filename_match.group(1).strip()
            else:
                filename = "default_output.png"
        else:
            filename = "default_output.png"
        
        filename = f"erased_{current_image_name}"
        erased_output_path = f"{ERASE_OUTPUT_PATH}/{filename}"
        os.makedirs(os.path.dirname(erased_output_path), exist_ok=True)
        
        with open(erased_output_path, "wb") as f:
            f.write(response.content)
        
        logger.info(f"Erase operation completed in {time.time() - erase_start:.3f}s")
        logger.info(f"Result path: {erased_output_path}")
        
        # Encode result to base64
        encode_start = time.time()
        erased_image = Image.open(erased_output_path)
        buffer = io.BytesIO()
        erased_image.save(buffer, format='PNG')
        base64_image = base64.b64encode(buffer.getvalue()).decode('utf-8')
        logger.info(f"Result encoded to base64 in {time.time() - encode_start:.3f}s")
        
        total_time = time.time() - start_time
        logger.info(f"✓ ERASE COMPLETED IN {total_time:.3f}s")
        logger.info("="*60)
        
        return EraseResponse(
            image=base64_image,
            message=f"Successfully erased object"
        )
        
    except Exception as e:
        logger.error(f"✗ ERASE FAILED after {time.time() - start_time:.3f}s: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error processing erase: {str(e)}")