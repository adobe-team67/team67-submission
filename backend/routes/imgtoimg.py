# app/routes/users.py
import logging
from fastapi import APIRouter
from backend.logger import setup_logger
import time
import os
from backend.models.models import EraseResponse, ImgToImgRequest
from backend.utils.savebas64 import save_base64_file
from fastapi import HTTPException
import httpx
from dotenv import load_dotenv
load_dotenv()
from utils.guardrails import final_img_guardrail, start_prompt_guardrail

logger = setup_logger("imgtoimg")

router = APIRouter(
    prefix="",
    tags=["imgtoimg"],
)

ORIGINAL_IMAGE_DIR = os.getenv("ORIGINAL_IMAGE_DIR", "data/original_from_frontend")
MASK_DIR = os.getenv("MASK_DIR", "data/masks_for_frontend")
OUTPUT_IMGTOIMG_DIR = os.getenv("OUTPUT_IMGTOIMG_DIR", "output/imgtoimg")
DETECTION_SEGMENTATION_URL = os.getenv("DETECTION_SEGMENTATION_URL", "http://10.36.16.96:8001")
FLUX_FEATURES_URL = os.getenv("FLUX_FEATURES_URL", "http://10.36.16.96:8006")




@router.post("/imgtoimg")
async def img_to_img(request: ImgToImgRequest):
    logger.info("Image-to-Image request received")
    
    prompt_check = start_prompt_guardrail(request.prompt)
    if prompt_check == "not right":
        raise HTTPException(
            status_code=400,
            detail="Prompt contains disallowed content"
        )
    try:
        payload = {
            "img": request.image,          # already fixed key name
            "prompt": request.prompt
        }

        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(
                f"{FLUX_FEATURES_URL}/imgtoimg",
                json=payload
            )

        if response.status_code != 200:
            raise HTTPException(
                status_code=response.status_code,
                detail=f"Image-to-Image service error: {response.text}"
            )

        data = response.json()

        if isinstance(data, str):
            generated_image_b64 = data
        elif isinstance(data, dict):
            generated_image_b64 = data.get("image") or data.get("result_image")
        else:
            raise ValueError(f"Unexpected inner response type: {type(data)}")

        os.makedirs(OUTPUT_IMGTOIMG_DIR, exist_ok=True)
        output_path = f"{OUTPUT_IMGTOIMG_DIR}/generated_{int(time.time()*1000)}.png"
        save_base64_file(
            generated_image_b64,
            output_path
        )
        final_img_check = final_img_guardrail(output_path)
        if final_img_check == "not_right":
            raise HTTPException(
                status_code=400,
                detail="Generated image contains disallowed content"
            )
        logger.info("Image-to-Image generation completed successfully")

        return EraseResponse(
            image=generated_image_b64,
            message="Image-to-Image generation successful"
        )

    except Exception as e:
        logger.error(f"Error in Image-to-Image generation: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Error processing Image-to-Image: {str(e)}"
        )