import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app import errors, metrics
from app.config import settings
from app.seed import run_seed
from app.routers import auth, green_lots, roasts, stats, users

log = logging.getLogger("uvicorn.error")


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Health responde solo cuando termina el lifespan de arranque (RF-16).
    for line in run_seed():
        (log.error if line.startswith("Error") else log.info)(line)
    yield


app = FastAPI(
    title="BrewTrack", openapi_url="/api/v1/openapi.json", docs_url="/api/v1/docs", lifespan=lifespan
)
errors.install(app)
app.add_middleware(
    CORSMiddleware, allow_origins=settings.cors_origins, allow_methods=["*"], allow_headers=["*"]
)
app.include_router(auth.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(green_lots.router, prefix="/api/v1")
app.include_router(roasts.router, prefix="/api/v1")
app.include_router(stats.router, prefix="/api/v1")


@app.get("/api/v1/health")
def health():
    return {"status": "ok"}


# Al final: necesita las rutas ya registradas para crear las series en 0.
metrics.install(app)
