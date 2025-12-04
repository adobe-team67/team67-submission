import os
import subprocess
import shlex

def download_all():
    
    os.makedirs('models', exist_ok=True)
    subprocess.run(shlex.split('wget https://huggingface.co/Adapter/DragonDiffusion/resolve/main/model/ip_sd15_64.bin -O models/ip_sd15_64.bin'))
    subprocess.run(shlex.split('wget https://huggingface.co/Adapter/DragonDiffusion/resolve/main/model/shape_predictor_68_face_landmarks.dat -O models/shape_predictor_68_face_landmarks.dat'))
    subprocess.run(shlex.split('wget https://huggingface.co/Adapter/DragonDiffusion/resolve/main/model/efficient_sam_vits.pt -O models/efficient_sam_vits.pt'))