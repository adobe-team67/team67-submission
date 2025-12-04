FROM nvidia/cuda:12.8.1-runtime-ubuntu22.04

WORKDIR /app

RUN apt-get update && apt-get install -y \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh \
    && bash miniconda.sh -b -p /opt/conda \
    && rm miniconda.sh

ENV PATH="/opt/conda/bin:${PATH}"

RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

COPY objectclearEnv.yml .
RUN conda env create -f objectclearEnv.yml

SHELL ["bash", "-lc"]

ENV CONDA_DEFAULT_ENV=objectclear
ENV PATH="/opt/conda/envs/objectclear/bin:${PATH}"

RUN pip install --no-cache-dir fastapi uvicorn[standard]
RUN apt-get update && apt-get install -y libgl1-mesa-glx
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libgl1-mesa-glx \
        libglib2.0-0 && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir psutil

COPY . .

RUN mkdir -p output

EXPOSE 8004

ENV PYTHONUNBUFFERED=1
ENV CUDA_VISIBLE_DEVICES=0
ENV HF_HOME=/app/.cache/huggingface

CMD ["python", "objectclearservice.py"]
