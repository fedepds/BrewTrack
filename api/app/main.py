from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app import errors
from app.config import settings
from app.routers import auth, green_lots, roasts, users

app = FastAPI(title="BrewTrack", openapi_url="/api/v1/openapi.json", docs_url="/api/v1/docs")
errors.install(app)
app.add_middleware(
    CORSMiddleware, allow_origins=settings.cors_origins, allow_methods=["*"], allow_headers=["*"]
)
app.include_router(auth.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(green_lots.router, prefix="/api/v1")
app.include_router(roasts.router, prefix="/api/v1")


@app.get("/api/v1/health")
def health():
    return {"status": "ok"}
