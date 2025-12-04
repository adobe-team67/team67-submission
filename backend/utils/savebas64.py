import base64
import os


def save_base64_file(base64_str: str, output_path: str):

    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    file_bytes = base64.b64decode(base64_str)
    with open(output_path, "wb") as f:
        f.write(file_bytes)

    return output_path
