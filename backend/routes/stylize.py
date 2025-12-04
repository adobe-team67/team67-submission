# app/routes/users.py
import logging
from fastapi import APIRouter
from backend.logger import setup_logger
import time
import os
from backend.models.models import img2imgResponse, StylizeRequest
from backend.utils.savebas64 import save_base64_file
from fastapi import HTTPException
import httpx
from dotenv import load_dotenv
from utils.guardrails import final_img_guardrail, start_prompt_guardrail
load_dotenv()


logger = setup_logger("stylize")

router = APIRouter(
    prefix="",
    tags=["stylize"],
)

ORIGINAL_IMAGE_DIR = os.getenv("ORIGINAL_IMAGE_DIR", "data/original_from_frontend")
MASK_DIR = os.getenv("MASK_DIR", "data/masks_for_frontend")
OUTPUT_IMGTOIMG_DIR = os.getenv("OUTPUT_IMGTOIMG_DIR", "output/imgtoimg")
DETECTION_SEGMENTATION_URL = os.getenv("DETECTION_SEGMENTATION_URL", "http://10.36.16.96:8001")
FLUX_FEATURES_URL = os.getenv("FLUX_FEATURES_URL", "http://10.36.16.96:8006")



@router.post("/stylize")
async def stylize_image(request: StylizeRequest):
    """Stylize image endpoint"""
    logger.info("Stylize image request received")
    selected_style = request.style if request.style else None 
    if selected_style is not None: #IF STYLE IS GIVEN
        if selected_style.lower() == "formal":
            prompt = "A person is sitting on a wooden chair with their hand resting on their chin, wearing a blue sweater vest and white pants, against a wooden background with a colorful rug on the floor."
            try:
                payload = {
                    "img": request.image,
                    "prompt": prompt
                }
                async with httpx.AsyncClient(timeout=120.0) as client:
                    response = await client.post(
                        f"{FLUX_FEATURES_URL}/imgtoimg",
                        json=payload
                    )
                    if response.status_code != 200:
                        raise HTTPException(
                            status_code=response.status_code,
                            detail=f"Two Images service error: {response.text}"
                        )
                    
                    data = response.json()
                metrics = data["metrics"]
                data = data["image"]
                if isinstance(data, str):
                    generated_image_b64 = data
                elif isinstance(data, dict):
                    generated_image_b64 = data.get("image") or data.get("result_image")
                else:
                    raise ValueError(f"Unexpected inner response type: {type(data)}")

                os.makedirs(OUTPUT_IMGTOIMG_DIR, exist_ok=True)
                save_base64_file(
                    generated_image_b64,
                    f"{OUTPUT_IMGTOIMG_DIR}/generated_{int(time.time()*1000)}.png"
                )

                logger.info("Image-to-Image generation completed successfully")

                return img2imgResponse(
                    image=generated_image_b64,
                    message="Image-to-Image generation successful",
                    metrics=metrics
                )

            except Exception as e:
                logger.error(f"Error in Image-to-Image generation: {str(e)}", exc_info=True)
                raise HTTPException(
                    status_code=500,
                    detail=f"Error processing Image-to-Image: {str(e)}"
                )
    elif request.target_image is not None:  #IF TARGET IMAGE IS GIVEN
        try:
            payload = {
                "img": request.target_image, # FIRST SEND TARGET IMAGE TO QWEN AND GET PROMPT
                "prompt": ""
            }
            # async with httpx.AsyncClient(timeout=120.0) as client:
            #     response = await client.post(
            #         "http://172.31.8.201:9000/routing",
            #         json=payload
            #     )
                
            #     if response.status_code != 200:
            #         raise HTTPException(
            #             status_code=response.status_code,
            #             detail=f"Two Images service error: {response.text}"
            #         )
                
                # prompt = response.text  #RECIEVED PROMPT
            prompt = "The person is seated in a chair with one leg crossed over the other. The head is tilted slightly to the side, and the hand is resting on the chin. The body is slightly leaned forward, and the arms are relaxed on the chair's armrests. The feet are positioned on the floor, with one foot slightly in front of the other."

            payload = {
                    "img": request.image, # SEND PROMPT AND ORIGINAL IMAGE TO FLUX
                    "prompt": prompt
                }
            async with httpx.AsyncClient(timeout=120.0) as client:
                response = await client.post(
                    f"{FLUX_FEATURES_URL}/imgtoimg",
                    json=payload
                )
                
                if response.status_code != 200:
                    raise HTTPException(
                        status_code=response.status_code,
                        detail=f"Two Images service error: {response.text}"
                    )
                
                data = response.json()
            metrics = data["metrics"]
            data = data["image"]
            if isinstance(data, str):
                generated_image_b64 = data
            elif isinstance(data, dict):
                generated_image_b64 = data.get("image") or data.get("result_image")
            else:
                raise ValueError(f"Unexpected inner response type: {type(data)}")

            os.makedirs(OUTPUT_IMGTOIMG_DIR, exist_ok=True)
            save_base64_file(
                generated_image_b64,
                f"{OUTPUT_IMGTOIMG_DIR}/generated_{int(time.time()*1000)}.png"
            )

            logger.info("Image-to-Image generation completed successfully")

            return img2imgResponse(
                image=generated_image_b64,
                message="Image-to-Image generation successful",
                metrics=metrics
            )

        except Exception as e:
            logger.error(f"Error in Image-to-Image generation: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=500,
                detail=f"Error processing Image-to-Image: {str(e)}"
            )
    else:  # IF ONLY PROMPT IS GIVEN
        prompt_check = start_prompt_guardrail(request.prompt)
        if prompt_check == "not right":
            logger.info("guardrails blocked the prompt")
            raise HTTPException(
                status_code=400,
                detail="Prompt contains disallowed content"
            )
        try:
            payload = {
                "img": request.image,
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
            metrics = data["metrics"]
            data = data["image"]
            if isinstance(data, str):
                generated_image_b64 = data
            elif isinstance(data, dict):
                generated_image_b64 = data.get("image") or data.get("result_image")
            else:
                raise ValueError(f"Unexpected inner response type: {type(data)}")

            os.makedirs(OUTPUT_IMGTOIMG_DIR, exist_ok=True)
            save_base64_file(
                generated_image_b64,
                f"{OUTPUT_IMGTOIMG_DIR}/generated_{int(time.time()*1000)}.png"
            )
            final_img_check = final_img_guardrail(output_path)
            if final_img_check == "not_right":
                logger.info("guardrails blocked the image")
                raise HTTPException(
                    status_code=400,
                    detail="Generated image contains disallowed content"
                )
            logger.info("Image-to-Image generation completed successfully")

            return img2imgResponse(
                image=generated_image_b64,
                message="Image-to-Image generation successful",
                metrics=metrics
            )

        except Exception as e:
            logger.error(f"Error in Image-to-Image generation: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=500,
                detail=f"Error processing Image-to-Image: {str(e)}"
            )