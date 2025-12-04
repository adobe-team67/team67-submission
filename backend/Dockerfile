FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
      build-essential \
      libffi-dev \
      openssl \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -m appuser

# ---- Set workdir ----
WORKDIR /app

COPY . /app/backend

RUN if [ -f /app/backend/requirements.txt ]; then \
      pip install --no-cache-dir -r /app/backend/requirements.txt; \
    else \
      pip install --no-cache-dir fastapi uvicorn; \
    fi

RUN mkdir -p /app/backend/data/original_from_frontend \
             /app/backend/data/masks_for_frontend \
             /app/backend/output/imgtoimg \
             /app/backend/output/inpaint \
             /app/backend/output/movedimages \
             /app/backend/logs && \
    chown -R appuser:appuser /app

USER appuser

WORKDIR /app/backend

EXPOSE 8000

CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]