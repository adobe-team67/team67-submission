import torch
from diffusers import FluxKontextInpaintPipeline,FluxPipeline,FluxKontextPipeline, GGUFQuantizationConfig
from diffusers.utils import load_image
from diffusers.hooks import apply_group_offloading
# from accelerate import cpu_offload
from diffusers import BitsAndBytesConfig as DiffusersBitsAndBytesConfig, FluxTransformer2DModel, FluxPipeline
from transformers import BitsAndBytesConfig as BitsAndBytesConfig, T5EncoderModel
from PIL import Image
from loguru import logger as lg


print("starting file")

def flux_impaint(img,mask,prompt):
    ckpt_path = ("flux1-kontext-dev-Q8_0.gguf")
    transformer = FluxTransformer2DModel.from_single_file(
        ckpt_path,
        quantization_config=GGUFQuantizationConfig(compute_dtype=torch.bfloat16),
        torch_dtype=torch.bfloat16,
        config="black-forest-labs/FLUX.1-Kontext-dev",
        subfolder="transformer",
    )
    lg.debug("latent dim:", transformer.config.in_channels)

    pipe = FluxKontextInpaintPipeline.from_pretrained(
        "black-forest-labs/FLUX.1-Kontext-dev",
        torch_dtype=torch.bfloat16,
        transformer=transformer
    )
    # pipe.enable_sequential_cpu_offload()
    # pipe.transformer.to("cuda")
    pipe.text_encoder.to("cuda")
    pipe.text_encoder_2.to("cuda")
    # pipe.vae.to("cuda")
    apply_group_offloading(pipe.transformer,offload_type="leaf_level",offload_device=torch.device("cpu"),onload_device=torch.device("cuda"),use_stream=True,)
    # apply_group_offloading(pipe.text_encoder,offload_type="leaf_level",offload_device=torch.device("cpu"),onload_device=torch.device("cuda"),use_stream=True,)
    # apply_group_offloading(pipe.text_encoder_2,offload_type="leaf_level",offload_device=torch.device("cpu"),onload_device=torch.device("cuda"),use_stream=True,)
    apply_group_offloading(pipe.vae,offload_type="leaf_level",offload_device=torch.device("cpu"),onload_device=torch.device("cuda"),use_stream=True,)
    prompt=prompt

    img_url = img
    mask_url = mask


    source = (img_url)
    mask = (mask_url)

    mask = pipe.mask_processor.blur(mask, blur_factor=12)
    image = pipe(
        prompt=prompt, image=source, mask_image=mask, strength=1.0,num_inference_steps=4
    ).images[0]
    return image



def flux_img_to_img(img,prompt):

    ckpt_path = ("flux1-kontext-dev-Q8_0.gguf")
    print("loading transformer")
    transformer = FluxTransformer2DModel.from_single_file(
        ckpt_path,
        quantization_config=GGUFQuantizationConfig(compute_dtype=torch.bfloat16),
        torch_dtype=torch.bfloat16,
        config="black-forest-labs/FLUX.1-Kontext-dev",
        subfolder="transformer",
    ) 
    print("transformer loaded")
    pipe = FluxKontextPipeline.from_pretrained( "black-forest-labs/FLUX.1-Kontext-dev", torch_dtype=torch.bfloat16, transformer=transformer)
    pipe.text_encoder.to("cuda")
    pipe.text_encoder_2.to("cuda")
    # pipe.vae.to("cuda")
    apply_group_offloading(pipe.transformer,offload_type="leaf_level",offload_device=torch.device("cpu"),onload_device=torch.device("cuda"),use_stream=True,)
    print("transformer offloaded")
    # apply_group_offloading(pipe.text_encoder,offload_type="leaf_level",offload_device=torch.device("cpu"),onload_device=torch.device("cuda"),use_stream=True,)
    # print("text encoder 1 offloaded")
    # apply_group_offloading(pipe.text_encoder_2,offload_type="leaf_level",offload_device=torch.device("cpu"),onload_device=torch.device("cuda"),use_stream=True,)
    # print("text encoder 2 offloaded")
    apply_group_offloading(pipe.vae,offload_type="leaf_level",offload_device=torch.device("cpu"),onload_device=torch.device("cuda"),use_stream=True,)
    print("vae offloaded")

    prompt = prompt
    seed = 42
    image = pipe(
        image=img,
        prompt=prompt,
        output_type="pil",
        num_inference_steps=10,
        generator=torch.Generator("cpu").manual_seed(seed)
    ).images[0]

    return image



if __name__=="__main__":
    img=Image.open("h.png")
    img=img.convert("RGB")
    mask=Image.open("h_mask.png")
    prompt="Place the person from the input image onto an elegant Vogue magazine cover. Preserve their face, pose, and identity while integrating them seamlessly into a high-fashion editorial layout with clean lighting, refined colors, and polished aesthetics. Add subtle magazine-style typography and minimalistic design elements typical of modern Vogue covers."

    res=flux_impaint(img, mask, prompt)
    res.save("h_vogue.png")
