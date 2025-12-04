# app/main.py
from fastapi import FastAPI
import uvicorn
from backend.routes.erase import router as erase_router
from backend.routes.imgtoimg import router as imgtoimg_router
from backend.routes.set_image import router as set_image_router
from backend.routes.set_masks import router as set_masks_router
from backend.routes.move import router as move_router
from backend.routes.stylize import router as stylize_router
from backend.routes.inpaint import router as inpaint_router
from fastapi.middleware.cors import CORSMiddleware


def create_app() -> FastAPI:
    app = FastAPI(
        title="Photoshop Backend",
        version="1.0.0",
        redirect_slashes=False,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(erase_router)
    app.include_router(imgtoimg_router)
    app.include_router(set_image_router)
    app.include_router(set_masks_router)
    app.include_router(move_router)
    app.include_router(stylize_router)
    app.include_router(inpaint_router)

    return app


app = create_app()



@app.get("/", tags=["root"])
async def read_root():
    return {"message": "Photoshop Backend is running!"}

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
