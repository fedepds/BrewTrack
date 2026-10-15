from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import field_validator
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str
    jwt_secret: str
    # Solo importa en desarrollo (flutter run); en producción nginx hace proxy same-origin.
    cors_origins: list[str] = ["http://localhost:5000"]
    # Zona del taller: define dónde empieza y termina cada mes en el resumen.
    timezone: str = "America/Argentina/Buenos_Aires"
    # Carga lotes y tuestes de ejemplo al iniciar (spec 002). Apagada si no se define.
    seed_demo_lots: bool = False

    @field_validator("timezone")
    @classmethod
    def _known_zone(cls, v: str) -> str:
        try:
            ZoneInfo(v)
        except (ZoneInfoNotFoundError, ValueError):
            raise ValueError(f"zona horaria desconocida: {v}")
        return v


settings = Settings()
