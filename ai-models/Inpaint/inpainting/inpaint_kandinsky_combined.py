import os
import torch
from diffusers import AutoPipelineForInpainting
from diffusers.utils import load_image, make_image_grid
from PIL import Image

os.makedirs("output_kandinsky", exist_ok=True)
os.makedirs("comparison_grid_kandinsky", exist_ok=True)

device = "cuda" if torch.cuda.is_available() else "cpu"
dtype = torch.float16 if device == "cuda" else torch.float32

print(f"Running on {device} using dtype {dtype}")

pipe = AutoPipelineForInpainting.from_pretrained(
    "kandinsky-community/kandinsky-2-2-decoder-inpaint",
    torch_dtype=dtype
)
pipe = pipe.to(device)

init_image = load_image("Images/image2.png").convert("RGB")
mask_image = load_image("Masks/mask2.png").convert("RGB")

prompt = "replace the bus in the image with a red car on the road"

result = pipe(
    prompt=prompt,
    image=init_image,
    mask_image=mask_image,
    num_images_per_prompt=1,
    num_inference_steps=40,
    guidance_scale=4.0,
    prior_guidance_scale=4.0,
    prior_num_inference_steps=40
)

output_image = result.images[0]
output_path = "output_kandinsky/output_image2.png"
output_image.save(output_path)

grid_path = "comparison_grid_kandinsky/comparison_grid_image2.png"
make_image_grid([init_image, mask_image, output_image], rows=1, cols=3).save(grid_path)

print("Done!")

