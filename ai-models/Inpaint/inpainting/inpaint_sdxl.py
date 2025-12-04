import os
import torch
from diffusers import StableDiffusionXLInpaintPipeline
from diffusers.utils import load_image, make_image_grid
from PIL import Image

os.makedirs("output_sdxl", exist_ok=True)
os.makedirs("comparison_grid_sdxl", exist_ok=True)

device = "cuda" if torch.cuda.is_available() else "cpu"
dtype = torch.float16 if device == "cuda" else torch.float32
print(f"Running SDXL Inpainting on: {device}, dtype: {dtype}")

pipe = StableDiffusionXLInpaintPipeline.from_pretrained(
    "stabilityai/stable-diffusion-xl-base-1.0",
    torch_dtype=dtype,
    use_safetensors=True,
)

if device == "cuda":
    pipe.to("cuda")
else:
    pipe.enable_model_cpu_offload()

image = load_image("Images/image2.png").convert("RGB")
mask = load_image("Masks/mask2.png").convert("RGB")

prompt = "replace the bus in the image with a red car on the road"

result = pipe(
    prompt=prompt,
    image=image,
    mask_image=mask,
    num_inference_steps=30,
    guidance_scale=7.5,
    generator=torch.Generator(device).manual_seed(42),
)

output_image = result.images[0]
output_path = "output_sdxl/output_image2.png"
grid_path = "comparison_grid_sdxl/comparison_grid_image2.png"

output_image.save(output_path)
make_image_grid([image, mask, output_image], rows=1, cols=3).save(grid_path)

print("Done!")
