# app/routes/users.py
import logging
from fastapi import APIRouter
from backend.logger import setup_logger
import time
import base64
import io
import os
from PIL import Image
from backend.models.models import InpaintRequest, InpaintResponse
from backend.utils.combinemasks import combine_bitmasks
from backend.utils.savebas64 import save_base64_file
from backend.utils.encodebase64 import encode_image_to_base64
from fastapi import HTTPException
import re
import httpx
import numpy as np
from utils.guardrails import final_img_guardrail, start_prompt_guardrail
from dotenv import load_dotenv
load_dotenv()


logger = setup_logger("inpaint")

router = APIRouter(
    prefix="",
    tags=["intpaint"],
)

ORIGINAL_IMAGE_DIR = os.getenv("ORIGINAL_IMAGE_DIR", "data/original_from_frontend")
MASK_DIR = os.getenv("MASK_DIR", "data/masks_for_frontend")
OUTPUT_DIR = os.getenv("OUTPUT_DIR", "output")
OUTPUT_INPAINT_DIR = os.getenv("OUTPUT_INPAINT_DIR", "output/inpaint")
INPAINT_URL = os.getenv("INPAINT_URL", "http://10.36.16.96:8002")
FLUX_INPAINT_URL = os.getenv("FLUX_INPAINT_URL", "http://10.36.16.96:8007")


@router.post("/inpaint")
async def inpaint_selection(request: InpaintRequest):
    """Inpaint selected region with user prompt"""
    manual_masks = request.manual_masks
    start_time = time.time()
    logger.info("="*60)
    logger.info("INPAINT REQUEST RECEIVED")
    logger.info(f"Prompt: {request.prompt}")
    prompt_check = start_prompt_guardrail(request.prompt)
    if prompt_check == "not right":
        logger.info("guardrails blocked the prompt")
        raise HTTPException(
            status_code=400,
            detail="Prompt contains disallowed content"
        )
    try:
        current_image_name = request.image_name
        current_original_image_path = f"{ORIGINAL_IMAGE_DIR}/{current_image_name}"
        mask_paths = []
        num = re.search(r'_(\d+)_', current_image_name).group(1)
        current_timestamp_mask = num
        if manual_masks is not None:
            # for i in manual_masks:
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
        if not current_original_image_path or not os.path.exists(current_original_image_path):
            logger.error("No original image found for inpaint operation")
            raise HTTPException(
                status_code=400,
                detail="No original image found. Please run /refine-selection first."
            )
        
        if not current_mask_path or not os.path.exists(current_mask_path):
            logger.error("No mask found for inpaint operation")
            raise HTTPException(
                status_code=400,
                detail="No mask found. Please run /refine-selection first."
            )
        
        logger.info(f"Using original image: {current_original_image_path}")
        logger.info(f"Using mask: {current_mask_path}")
        
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        os.makedirs(OUTPUT_INPAINT_DIR, exist_ok=True)
        
        timestamp = int(time.time() * 1000)
        image_b64 = encode_image_to_base64(current_original_image_path)
        mask_b64 = encode_image_to_base64(current_mask_path)
        data = {
            "img_base64": image_b64,
            "mask_base64": mask_b64,
            "prompt": request.prompt if request.prompt else ""
        }
        if request.model_type=="FREE":
            logger.info("Using FREE inpaint model")
            async with httpx.AsyncClient(timeout=120.0) as client:
                logger.info("USING FREE INPAINT MODEL", INPAINT_URL)
                response = await client.post(
                    f"{INPAINT_URL}/inpaint",
                    data=data
                )
                
                if response.status_code != 200:
                    raise HTTPException(
                        status_code=response.status_code,
                        detail=f"Erase service error: {response.text}"
                    )
        elif request.model_type == "PRO":
            logger.info("Using PRO inpaint model")
            async with httpx.AsyncClient(timeout=120.0) as client:
                response = await client.post(
                    f"{FLUX_INPAINT_URL}/flux-inpaint",
                    data=data
                )
                
                if response.status_code != 200:
                    raise HTTPException(
                        status_code=response.status_code,
                        detail=f"Erase service error: {response.text}"
                    )
        json = response.json()
        logger.info(f"Response JSON: {json}")
        output_image_b64 = json["image"]
        logger.info(output_image_b64[:30])
        metrics = json["metrics"]
        inpainted_image_path = f"{OUTPUT_INPAINT_DIR}/inpainted_image_{int(time.time()*1000)}.png"
        save_base64_file(output_image_b64, inpainted_image_path)
        image = Image.open(inpainted_image_path)
        buffer = io.BytesIO()
        image.save(buffer, format='PNG')
        base64_image = base64.b64encode(buffer.getvalue()).decode('utf-8')
        final_img_check = final_img_guardrail(inpainted_image_path)
        if final_img_check == "not_right":
            logger.info("guardrails blocked the image")
            raise HTTPException(
                status_code=400,
                detail="Generated image contains disallowed content"
            )
        total_time = time.time() - start_time
        logger.info(f"✓ INPAINT COMPLETED IN {total_time:.3f}s")
        logger.info("="*60)
        
        return InpaintResponse(
            image=base64_image,
            message=f"Successfully inpainted with prompt: {request.prompt}",
            metrics=metrics
        )
        
    except Exception as e:
        logger.error(f"✗ INPAINT FAILED after {time.time() - start_time:.3f}s: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Error processing inpaint: {str(e)}")