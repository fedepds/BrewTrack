from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app import errors
from app.config import settings

app = FastAPI(title="BrewTrack", openapi_url="/api/v1/openapi.json", docs_url="/api/v1/docs")
errors.install(app)
app.add_middleware(
    CORSMiddleware, allow_origins=settings.cors_origins, allow_methods=["*"], allow_headers=["*"]
)


@app.get("/api/v1/health")
def health():
    return {"status": "ok"}
