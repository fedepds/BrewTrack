from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import ValidationError, field_validator
from pydantic_settings import BaseSettings


# Valor de ejemplo de .env.example: nunca vale como secreto real.
TEMPLATE_JWT_SECRET = "change-me-with-at-least-32-characters"


class Settings(BaseSettings):
    database_url: str
    jwt_secret: str
    # Solo importa en desarrollo (flutter run); en producción nginx hace proxy same-origin.
    cors_origins: list[str] = ["http://localhost:5000"]
    # Zona del taller: define dónde empieza y termina cada mes en el resumen.
    timezone: str = "America/Argentina/Buenos_Aires"
    # Carga lotes y tuestes de ejemplo al iniciar (spec 002). Apagada si no se define.
    seed_demo_lots: bool = False
    # Admin inicial: se crea al arrancar si las dos están definidas y no hay usuarios.
    seed_admin_email: str = ""
    seed_admin_password: str = ""

    @field_validator("jwt_secret")
    @classmethod
    def _strong_secret(cls, v: str) -> str:
        # Los mensajes no incluyen v: el secreto no sale en ninguna salida.
        if len(v) < 32:
            raise ValueError("JWT_SECRET tiene menos de 32 caracteres")
        if v == TEMPLATE_JWT_SECRET:
            raise ValueError("JWT_SECRET es el valor de la plantilla .env.example")
        return v

    @field_validator("seed_admin_password")
    @classmethod
    def _admin_password(cls, v: str) -> str:
        # Vacía significa "no crear admin". El mínimo es el mismo que el de create-admin.
        if v and len(v) < 8:
            raise ValueError("SEED_ADMIN_PASSWORD tiene menos de 8 caracteres")
        return v

    @field_validator("timezone")
    @classmethod
    def _known_zone(cls, v: str) -> str:
        try:
            ZoneInfo(v)
        except (ZoneInfoNotFoundError, ValueError):
            raise ValueError(f"zona horaria desconocida: {v}")
        return v


def _load() -> Settings:
    try:
        return Settings()
    except ValidationError as e:
        # include_input=False: pydantic imprimiría input_value, que puede ser el secreto.
        lines = [f"- {'.'.join(map(str, err['loc'])).upper()}: {err['msg']}"
                 for err in e.errors(include_input=False, include_url=False, include_context=False)]
        raise SystemExit("Configuración inválida, la API no arranca:\n" + "\n".join(lines))


settings = _load()
