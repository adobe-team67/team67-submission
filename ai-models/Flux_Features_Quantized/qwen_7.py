
import torch
from transformers import Qwen2VLForConditionalGeneration, AutoTokenizer, AutoProcessor
import gc


def qwen(img_path, model, processor, prompt=""):


    # model = Qwen2VLForConditionalGeneration.from_pretrained("Qwen/Qwen2-VL-7B-Instruct", device_map="cpu")
    # processor = AutoProcessor.from_pretrained("Qwen/Qwen2-VL-7B-Instruct")


    conversation = [
        {
            "role":"user",
            "content":[
                {
                    "type":"image",
                    "url": img_path
                },
                {
                    "type":"text",
                    "text":'''You are an expert human-pose extraction model.

                            Task:
                            Given an input image, describe ONLY the person's body pose in precise detail.

                            Rules:
                            - ONLY describe the pose: body orientation, head direction, limb positions, angles, gesture.
                            - DO NOT mention age, gender, face, clothes, style, background, lighting, or identity.
                            - No adjectives about appearance.
                            - No interpretation or emotion.
                            - Keep it factual and mechanical, like pose-skeleton data.

                            Output Format:
                            A single short paragraph describing the pose.
                            '''
                }
            ]
        }
    ]

    inputs = processor.apply_chat_template(
        conversation,
        add_generation_prompt=True,
        tokenize=True,
        return_dict=True,
        return_tensors="pt"
    ).to(model.device)

    output_ids = model.generate(**inputs, max_new_tokens=128)
    generated_ids = [output_ids[len(input_ids):] for input_ids, output_ids in zip(inputs.input_ids, output_ids)]
    output_text = processor.batch_decode(generated_ids, skip_special_tokens=True, clean_up_tokenization_spaces=True)
    # del model
    # del processor
    del inputs
    del output_ids
    del generated_ids
    gc.collect()
    torch.cuda.empty_cache()
    return output_text

