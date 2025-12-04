FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

WORKDIR /app

RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    python3.10 \
    python3-pip \
    git \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

RUN pip3 install --no-cache-dir fastapi uvicorn[standard] einops basicsr
RUN pip3 install --no-cache-dir python-multipart
RUN pip3 install --no-cache-dir pynvml

COPY . .

RUN mkdir -p data/erase

EXPOSE 8003

ENV PYTHONUNBUFFERED=1
ENV CUDA_VISIBLE_DEVICES=0

CMD ["python3", "inpaint_service.py"]
