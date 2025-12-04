def start_prompt_guardrail(prompt):
    import nltk
    from nltk.corpus import stopwords
    from nltk.tokenize import word_tokenize

    nltk.download("stopwords", quiet=True)
    nltk.download("punkt", quiet=True)

    nudity_words = {
        "nude", "nudity", "naked", "nsfw", "boobs", "breast", "butt",
        "ass", "porn", "erotic", "genitals", "sexual", "sex"
    }

    drug_words = {
        "drugs", "drug", "cocaine", "weed", "marijuana", "heroin", "meth",
        "lsd", "ecstasy", "amphetamine", "opioid", "opium", "ketamine"
    }

    self_harm_words = {
        "suicide", "suicidal", "self-harm", "selfharm", "kill myself",
        "cutting", "hang", "harm myself"
    }

    violence_words = {
        "murder", "kill", "killing", "stab", "shoot", "blood",
        "violence", "violent"
    }

    blocked = nudity_words | drug_words | self_harm_words | violence_words

    tokens = word_tokenize(prompt.lower())

    for w in tokens:
        if w in blocked:
            return "not right"

    return "all clear"





def final_img_guardrail(img_path):
    import torch
    from transformers import Qwen2VLForConditionalGeneration, AutoTokenizer, AutoProcessor
    from PIL import Image
    def qwen(img_path):
        s = time.time()


        model = Qwen2VLForConditionalGeneration.from_pretrained("Qwen/Qwen2-VL-7B-Instruct", device_map="cpu")
        processor = AutoProcessor.from_pretrained("Qwen/Qwen2-VL-7B-Instruct")


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
                        "text":"check if the given image has ank kind of nuduity ,self harm volience if it has then return not_right  else return all_clear"
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
        end_time = time.time()
        elapsed_time = end_time - s
        return output_text
    qwen_response = qwen(img_path=img_path)
    return qwen_response[0]

if __name__=="__main__":
    print(start_prompt_guardrail("make this person joker"))

