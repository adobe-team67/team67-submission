# Backend

A production-ready FastAPI backend that orchestrates multiple AI model microservices, each packaged as an isolated Dockerized FastAPI service. The backend exposes a unified API for the app, delegating feature-specific work (erase, move, inpaint, stylize/img2img) to the appropriate AI service and returning results.

## Overview

- The main backend is in `backend/` and exposes a unified API to the photo-editing app.
- Each AI feature lives in `ai-models/<Feature>/` with its own code, dependencies, and Dockerfile.
- The backend calls AI services over HTTP using service URLs configured via environment variables.

### Services in this repository

- Move: `ai-models/Move/` → FastAPI service on port `8001` (POST `/move3`)
- Inpaint (FREE): `ai-models/Inpaint/` → FastAPI service on port `8002` (POST `/inpaint`)
- Erase: `ai-models/Erase/` → FastAPI service on port `8005` (POST `/erase`)
- Flux Features (Quantized): `ai-models/Flux_Features_Quantized/` → FastAPI service on port `8006` (POST `/imgtoimg`)
- Flux Inpaint (Quantized): `ai-models/Flux_Inpaint_Quantized/` → FastAPI service on port `8007` (POST `/flux-inpaint`)

Backend routes call these services using environment variables loaded from `/backend/.env`:

- `DETECTION_SEGMENTATION_URL` → Move service (default port 8001)
- `INPAINT_URL` → Inpaint (FREE) service (default port 8002)
- `ERASE_URL` → Erase service (default port 8005)
- `FLUX_FEATURES_URL` → Flux Features (default port 8006)
- `FLUX_INPAINT_URL` → Flux Inpaint (default port 8007)

Additional directories (input/output/logs) are also configured via env vars in `.env`.

## Local Setup and Run (Recommended)

This section provides step-by-step instructions to run the whole system locally.

### Prerequisites

- Docker and Docker Compose v2
- Optional: Python 3.10+ (only needed if you want to run backend without Docker)

### Repo layout (relevant)

```
/
  ai-models/
    - Erase/
    - Flux_Features_Quantized/
    - Flux_Inpaint_Quantized/
    - Inpaint/
    - Move/
  backend/
    - .env
    - Dockerfile
    - main.py
    - routes/
    - models/
    - utils/
    - logs/
```

### Option A: Run each AI service container individually

From `/` run these in separate terminals (or sequentially):

```bash
# Move (port 8001)
docker build -t -move:local ./ai-models/Move
docker run --rm -p 8001:8001 --name move -move:local

# Inpaint (port 8002)
docker build -t -inpaint:local ./ai-models/Inpaint
docker run --rm -p 8002:8002 --name inpaint -inpaint:local

# Erase (port 8005)
docker build -t -erase:local ./ai-models/Erase
docker run --rm -p 8005:8005 --name erase -erase:local

# Flux Features (port 8006)
docker build -t -flux-features:local ./ai-models/Flux_Features_Quantized
docker run --rm -p 8006:8006 --name flux_features -flux-features:local

# Flux Inpaint (port 8007)
docker build -t -flux-inpaint:local ./ai-models/Flux_Inpaint_Quantized
docker run --rm -p 8007:8007 --name flux_inpaint -flux-inpaint:local
```

Then run the backend (Docker):

```bash
# Backend (port 8000)
docker build -t -backend:local ./backend
# Point the backend to local containers with env vars
docker run --rm -p 8000:8000 \
  -e ERASE_URL=http://host.docker.internal:8005 \
  -e INPAINT_URL=http://host.docker.internal:8002 \
  -e FLUX_INPAINT_URL=http://host.docker.internal:8007 \
  -e FLUX_FEATURES_URL=http://host.docker.internal:8006 \
  -e DETECTION_SEGMENTATION_URL=http://host.docker.internal:8001 \
  --name backend -backend:local
```

Linux note: `host.docker.internal` may not resolve by default; use the host IP (e.g., `172.17.0.1`) or run everything via Docker Compose so names resolve automatically.

### Option B: Run backend locally (Python) with Dockerized AI services

1. Start the AI containers (Option B above).

2. Install backend dependencies and run the server:

```bash
cd /backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
# Edit .env to point to AI service URLs (see below)
uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
```

### Configure backend URLs

The backend reads `/backend/.env`. When using Docker Compose, the services resolve by name; when running locally, set reachable URLs (localhost or host IP).

Recommended `.env` for Compose-based local dev:

```dotenv
# Service URLs (Docker DNS names)
ERASE_URL=http://erase:8005
INPAINT_URL=http://inpaint:8002
FLUX_INPAINT_URL=http://flux_inpaint:8007
FLUX_FEATURES_URL=http://flux_features:8006
DETECTION_SEGMENTATION_URL=http://move:8001

# I/O paths
ORIGINAL_IMAGE_DIR=data/original_from_frontend
MASK_DIR=data/masks_for_frontend
OUTPUT_DIR=output
OUTPUT_IMGTOIMG_DIR=output/imgtoimg
OUTPUT_INPAINT_DIR=output/inpaint
OUTPUT_MOVE_DIR=output/movedimages
ERASE_OUTPUT_PATH=output/erasedimages

HOST=0.0.0.0
PORT=8000
```

If running backend locally, switch the URLs to `http://localhost:<port>`.

## Testing

Quick checks:

```bash
# Backend alive
curl -s http://localhost:8000/ | jq .

# Move service health
curl -s http://localhost:8001/health | jq .

# Erase service health
curl -s http://localhost:8005/health | jq .
```

Endpoint smoke tests (examples):

- Img-to-Img via backend (requires base64 of an image):

```bash
IMG64=$(base64 -w 0 path/to/image.png)
curl -s -X POST http://localhost:8000/imgtoimg \
  -H 'Content-Type: application/json' \
  -d '{"image":"'"$IMG64"'","prompt":"A softer, painterly style"}' | jq .
```

- Inpaint (FREE) via backend expects `img_base64`, `mask_base64` (as Form data). Use a REST client (Postman/Insomnia) or a small script to send form-encoded fields.

- Erase via backend expects multipart `image` + `mask` file upload. Use Postman/Insomnia for convenience.

If an endpoint fails, check container logs:

```bash
# Compose
cd 
docker compose logs -f backend
docker compose logs -f move erase inpaint flux_features flux_inpaint

# Or individual containers
docker logs -f backend
```
