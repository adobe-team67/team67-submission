import torch
from diffusers import AutoPipelineForInpainting
from diffusers.utils import load_image, make_image_grid
from PIL import Image, ImageOps
import os

def run_inpaint(
    image_path,
    mask_path,
    prompt,
    pipeline,
    generator,
    device,
    output_dir="/app/data/inpainted/",
    grid_dir="comparison_grid_sd",
    steps=30,
    guidance=7.5,
    seed=92,
    model_id="runwayml/stable-diffusion-inpainting"
):
    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(grid_dir, exist_ok=True)

    init_image = Image.open(image_path).convert("RGB")
    mask_image = Image.open(mask_path).convert("L") 
    mask_image = ImageOps.invert(mask_image) 

    if device == "cuda":
        pipeline.to("cuda")
    else:
        pipeline.enable_model_cpu_offload()

    print("Starting inference...")

    result = pipeline(
        prompt=prompt,
        image=init_image,
        mask_image=mask_image,
        generator=generator,
        num_inference_steps=steps,
        guidance_scale=guidance
    )

    output_image = result.images[0]
    output_path = os.path.join(output_dir, os.path.basename(image_path).replace(".png", "_out.png"))
    grid_path = os.path.join(grid_dir, os.path.basename(image_path).replace(".png", "_grid.png"))

    output_image.save(output_path)
    make_image_grid([init_image, mask_image, output_image], rows=1, cols=3).save(grid_path)

    print("Done!")
    return output_path, grid_path


if __name__ == "__main__":
    run_inpaint()