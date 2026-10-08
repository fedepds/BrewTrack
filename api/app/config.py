from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str
    jwt_secret: str
    access_ttl_min: int = 60
    refresh_ttl_days: int = 7
    # Solo importa en desarrollo (flutter run); en producción nginx hace proxy same-origin.
    cors_origins: list[str] = ["http://localhost:5000"]


settings = Settings()
