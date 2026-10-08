# BrewTrack v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** API FastAPI + frontend Flutter Web + PostgreSQL, todo en contenedores Podman, para registrar lotes de café verde y tuestes con trazabilidad lote → tueste.

**Architecture:** Tres contenedores (`db`, `api`, `web`). `web` es nginx sirviendo el build de Flutter y haciendo proxy de `/api/` hacia `api:8000`. La API es FastAPI síncrona con SQLAlchemy 2 + Alembic, auth JWT con roles. El frontend usa Riverpod + go_router + dio, con modelos Dart a mano.

**Tech Stack:** Python 3.13, FastAPI, SQLAlchemy 2, psycopg 3, Alembic, argon2-cffi, PyJWT, pytest; Flutter Web (Material 3), flutter_riverpod 2.x, go_router, dio, shared_preferences; PostgreSQL 17; Podman (rootless) + `podman compose`.

**Spec:** `docs/superpowers/specs/2026-10-07-brewtrack-design.md`

## Global Constraints

- Prefijo de API: `/api/v1`. OpenAPI en `/api/v1/openapi.json`. Health en `/api/v1/health`.
- Errores siempre `{"error": {"code": "...", "message": "..."}}`. Códigos: 401, 403, 404, 409, 422.
- JWT HS256: acceso 1 h, refresh 7 días. Contraseñas con argon2. Secreto JWT desde `JWT_SECRET`.
- Roles: `roaster` y `admin`. Sin auto-registro; primer admin con `python -m app.cli create-admin`.
- Tablas: `users`, `green_lots`, `roasts`; ids UUID; `created_at`/`updated_at`. Stock de lote nunca se guarda: `received_kg - sum(green_in_kg)`.
- `roasts.lot_id` es `ON DELETE RESTRICT`. Un tueste no puede superar el stock disponible del lote.
- Imágenes: `postgres:17-alpine`, `python:3.13-slim` (multi-stage, usuario no root), build `ghcr.io/cirruslabs/flutter` + runtime `nginx:alpine`. Archivos llamados `Containerfile`. Imágenes con nombre completo (`docker.io/library/...`) para que Podman no pregunte.
- Solo `web` publica puerto al host (8080). Rootless.
- Frontend: Material 3, sin cliente OpenAPI generado, token de acceso en memoria y refresh token en `localStorage` (vía `shared_preferences`).
- Idioma de la UI: español.
- Config en `.env` (no versionado) + `.env.example`: `POSTGRES_PASSWORD`, `JWT_SECRET`, `DATABASE_URL`.

## Review Focus

Entradas/condiciones que la spec implica pero no detalla; cada una tiene su test en la tarea indicada.

1. Un refresh token presentado como access token debe dar 401 (Task 3).
2. Un token válido de un usuario desactivado después debe dar 401 (Task 3).
3. Desactivar o degradar al último admin activo debe dar 409 `last_admin` (Task 4).
4. Bajar `received_kg` de un lote por debajo de lo ya tostado debe dar 409 (Task 5).
5. Un tueste que consume exactamente el stock restante es válido; 0.001 kg más es 409 (Task 6). En el frontend, pesos vacíos o en cero muestran `Merma: —` y no revientan (Task 10).

---

## File Structure

```
.gitignore
compose.yaml
.env.example
README.md
api/
  Containerfile
  pyproject.toml
  alembic.ini
  alembic/env.py, script.py.mako, versions/0001_initial.py
  app/
    __init__.py
    config.py        # Settings desde entorno
    db.py            # engine, SessionLocal, Base, get_db
    errors.py        # ApiError, handlers, commit_or_409
    models.py        # User, GreenLot, Roast
    security.py      # argon2 + JWT
    deps.py          # current_user, admin_only
    schemas.py       # salidas compartidas (UserOut, LotOut, RoastOut...)
    stock.py         # stock de lotes
    cli.py           # create-admin
    main.py
    routers/auth.py, users.py, green_lots.py, roasts.py
  tests/conftest.py, test_health.py, test_models.py, test_auth.py, test_cli.py,
        test_users.py, test_green_lots.py, test_roasts.py
web/
  Containerfile, nginx.conf, .containerignore
  pubspec.yaml
  lib/main.dart, models.dart, util.dart, api.dart, providers.dart, router.dart,
      widgets.dart, edit_dialog.dart, shell.dart, login_screen.dart,
      lot_form.dart, lots_screen.dart, lot_detail_screen.dart,
      roast_form.dart, roasts_screen.dart, roast_detail_screen.dart, users_screen.dart
  test/util_test.dart, shell_test.dart, roast_form_test.dart
```

---

### Task 1: Esqueleto de la API (config, db, errores, health)

**Files:**
- Create: `.gitignore`, `api/pyproject.toml`, `api/app/__init__.py`, `api/app/config.py`, `api/app/db.py`, `api/app/errors.py`, `api/app/main.py`
- Test: `api/tests/conftest.py`, `api/tests/test_health.py`

**Interfaces:**
- Produces: `app.config.settings` (`database_url`, `jwt_secret`, `access_ttl_min`, `refresh_ttl_days`, `cors_origins`); `app.db.Base`, `engine`, `SessionLocal`, `get_db()`; `app.errors.ApiError(status, code, message)`, `errors.install(app)`, `commit_or_409(db, code, message)`; `app.main.app`.

- [ ] **Step 1: Crear entorno y dependencias**

Requiere Python >= 3.12 (`python3 --version`; si no, `brew install python@3.13`).

```bash
cd /Users/federicopizarro/Desktop/3
mkdir -p api/app api/tests
cat > .gitignore <<'EOF'
.venv/
__pycache__/
*.egg-info/
.pytest_cache/
.env
.dart_tool/
web/build/
.idea/
.DS_Store
EOF
cat > api/pyproject.toml <<'EOF'
[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"

[project]
name = "brewtrack-api"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
  "fastapi>=0.115",
  "uvicorn[standard]>=0.30",
  "sqlalchemy>=2.0",
  "psycopg[binary]>=3.2",
  "alembic>=1.13",
  "pydantic[email]>=2.8",
  "pydantic-settings>=2.4",
  "argon2-cffi>=23.1",
  "pyjwt>=2.9",
]

[project.optional-dependencies]
dev = ["pytest>=8", "httpx>=0.27"]

[tool.setuptools.packages.find]
include = ["app*"]

[tool.pytest.ini_options]
testpaths = ["tests"]
EOF
touch api/app/__init__.py
cd api && python3 -m venv .venv && . .venv/bin/activate && pip install -e ".[dev]"
```
Expected: `Successfully installed ... brewtrack-api-0.1.0`.

- [ ] **Step 2: Escribir los tests que fallan**

`api/tests/conftest.py`:
```python
import os

os.environ.setdefault("DATABASE_URL", "postgresql+psycopg://postgres:test@localhost:55432/brewtrack_test")
os.environ.setdefault("JWT_SECRET", "test-secret-test-secret-test-secret")

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    return TestClient(app)
```

`api/tests/test_health.py`:
```python
def test_health(client):
    r = client.get("/api/v1/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_unknown_route_uses_error_envelope(client):
    r = client.get("/api/v1/nope")
    assert r.status_code == 404
    assert r.json()["error"]["code"] == "http_error"
```

- [ ] **Step 3: Verificar que fallan**

Run: `cd api && pytest tests/test_health.py -v`
Expected: FAIL/ERROR con `ModuleNotFoundError: No module named 'app.main'`.

- [ ] **Step 4: Implementar**

`api/app/config.py`:
```python
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str
    jwt_secret: str
    access_ttl_min: int = 60
    refresh_ttl_days: int = 7
    # Solo importa en desarrollo (flutter run); en producción nginx hace proxy same-origin.
    cors_origins: list[str] = ["http://localhost:5000"]


settings = Settings()
```

`api/app/db.py`:
```python
from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import settings

engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(engine, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_db() -> Iterator[Session]:
    with SessionLocal() as db:
        yield db
```

`api/app/errors.py`:
```python
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from starlette.exceptions import HTTPException as StarletteHTTPException


class ApiError(Exception):
    def __init__(self, status: int, code: str, message: str):
        self.status, self.code, self.message = status, code, message


def _body(code: str, message: str) -> dict:
    return {"error": {"code": code, "message": message}}


def commit_or_409(db: Session, code: str, message: str) -> None:
    """Commit; una violación de unicidad/FK se traduce a 409."""
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise ApiError(409, code, message)


def install(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def _api(_: Request, e: ApiError):
        return JSONResponse(_body(e.code, e.message), status_code=e.status)

    @app.exception_handler(StarletteHTTPException)
    async def _http(_: Request, e: StarletteHTTPException):
        return JSONResponse(_body("http_error", str(e.detail)), status_code=e.status_code)

    @app.exception_handler(RequestValidationError)
    async def _validation(_: Request, e: RequestValidationError):
        def one(x: dict) -> str:
            loc = ".".join(str(p) for p in x["loc"][1:])
            return f"{loc}: {x['msg']}" if loc else x["msg"]

        return JSONResponse(_body("validation_error", "; ".join(one(x) for x in e.errors())), status_code=422)
```

`api/app/main.py`:
```python
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
```

- [ ] **Step 5: Verificar que pasan**

Run: `cd api && pytest tests/test_health.py -v`
Expected: 2 passed.

- [ ] **Step 6: Commit**

```bash
cd /Users/federicopizarro/Desktop/3
git add .gitignore api
git commit -m "feat(api): skeleton with config, db, error envelope and health"
```

---

### Task 2: Modelos y migración inicial

**Files:**
- Create: `api/app/models.py`, `api/alembic.ini`, `api/alembic/env.py`, `api/alembic/script.py.mako`, `api/alembic/versions/0001_initial.py` (autogenerado)
- Modify: `api/tests/conftest.py` (reemplazo completo)
- Test: `api/tests/test_models.py`

**Interfaces:**
- Consumes: `app.db.Base`, `engine`, `SessionLocal`.
- Produces: `User(email, password_hash, name, role, active)`, `GreenLot(code, origin_country, region, farm, producer, variety, process, altitude_m, harvest_year, received_at, received_kg, notes)` con `.roasts`, `Roast(lot_id, roaster_id, roasted_at, green_in_kg, roasted_out_kg, loss_pct, duration_s, drop_temp_c, roast_level, notes)` con `.lot`, `.roaster`, `.lot_code`, `.roaster_name`. Todos con `id` (UUID), `created_at`, `updated_at`. Fixtures `db` (Session) y esquema creado por Alembic una vez por sesión de pytest; tablas truncadas tras cada test.

- [ ] **Step 1: Levantar Postgres de pruebas con Podman**

```bash
podman machine start 2>/dev/null || true
podman run -d --name brewtrack-test-db -e POSTGRES_PASSWORD=test -e POSTGRES_DB=brewtrack_test \
  -p 55432:5432 docker.io/library/postgres:17-alpine
until podman exec brewtrack-test-db pg_isready -U postgres; do sleep 1; done
```
Expected: `/var/run/postgresql:5432 - accepting connections`.

- [ ] **Step 2: Escribir los tests que fallan**

`api/tests/test_models.py`:
```python
from datetime import date, datetime, timezone
from decimal import Decimal

import pytest
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from app.models import GreenLot, Roast, User


def _setup(db):
    user = User(email="a@x.com", password_hash="x", name="A", role="admin")
    lot = GreenLot(
        code="GL-1", origin_country="Colombia", variety="Caturra", process="washed",
        harvest_year=2026, received_at=date(2026, 1, 1), received_kg=Decimal("60"),
    )
    db.add_all([user, lot])
    db.commit()
    return user, lot


def _roast(lot, user, **kw):
    base = dict(
        lot_id=lot.id, roaster_id=user.id, roasted_at=datetime(2026, 2, 1, tzinfo=timezone.utc),
        green_in_kg=Decimal("10"), roasted_out_kg=Decimal("8.5"), loss_pct=Decimal("15.00"),
        duration_s=600, drop_temp_c=Decimal("205.0"), roast_level="medium",
    )
    return Roast(**{**base, **kw})


def test_defaults_are_filled(db):
    user, lot = _setup(db)
    db.refresh(lot)
    assert lot.id is not None and lot.created_at is not None and user.active is True


def test_roast_out_cannot_exceed_in(db):
    user, lot = _setup(db)
    db.add(_roast(lot, user, roasted_out_kg=Decimal("10.5")))
    with pytest.raises(IntegrityError):
        db.commit()


def test_invalid_role_and_level_rejected(db):
    user, lot = _setup(db)
    db.add(_roast(lot, user, roast_level="burnt"))
    with pytest.raises(IntegrityError):
        db.commit()
    db.rollback()
    db.add(User(email="b@x.com", password_hash="x", name="B", role="boss"))
    with pytest.raises(IntegrityError):
        db.commit()


def test_lot_with_roasts_cannot_be_deleted_in_db(db):
    user, lot = _setup(db)
    db.add(_roast(lot, user))
    db.commit()
    with pytest.raises(IntegrityError):
        db.execute(text("DELETE FROM green_lots WHERE id = :i"), {"i": lot.id})
        db.commit()
```

- [ ] **Step 3: Reemplazar `api/tests/conftest.py`**

```python
import os
from pathlib import Path

os.environ.setdefault("DATABASE_URL", "postgresql+psycopg://postgres:test@localhost:55432/brewtrack_test")
os.environ.setdefault("JWT_SECRET", "test-secret-test-secret-test-secret")

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import text

from app.db import SessionLocal, engine
from app.main import app

ALEMBIC_INI = Path(__file__).parent.parent / "alembic.ini"


@pytest.fixture(scope="session", autouse=True)
def _schema():
    cfg = Config(str(ALEMBIC_INI))
    command.downgrade(cfg, "base")  # por si una corrida anterior murió a medias
    command.upgrade(cfg, "head")
    yield
    command.downgrade(cfg, "base")


@pytest.fixture(autouse=True)
def _clean():
    yield
    with engine.begin() as c:
        c.execute(text("TRUNCATE roasts, green_lots, users CASCADE"))


@pytest.fixture
def db():
    with SessionLocal() as s:
        yield s


@pytest.fixture
def client():
    return TestClient(app)
```

- [ ] **Step 4: Verificar que fallan**

Run: `cd api && pytest tests/test_models.py -v`
Expected: ERROR (`alembic.ini` / `app.models` no existen).

- [ ] **Step 5: Implementar modelos**

`api/app/models.py`:
```python
import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint, Date, DateTime, ForeignKey, Index, Numeric, String, Text, Uuid, func, true,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class Timestamps:
    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class User(Base, Timestamps):
    __tablename__ = "users"
    email: Mapped[str] = mapped_column(String(255), unique=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    name: Mapped[str] = mapped_column(String(120))
    role: Mapped[str] = mapped_column(String(20))
    active: Mapped[bool] = mapped_column(default=True, server_default=true())
    __table_args__ = (CheckConstraint("role IN ('roaster','admin')", name="ck_users_role"),)


class GreenLot(Base, Timestamps):
    __tablename__ = "green_lots"
    code: Mapped[str] = mapped_column(String(40), unique=True)
    origin_country: Mapped[str] = mapped_column(String(80))
    region: Mapped[str | None] = mapped_column(String(120))
    farm: Mapped[str | None] = mapped_column(String(120))
    producer: Mapped[str | None] = mapped_column(String(120))
    variety: Mapped[str] = mapped_column(String(120))
    process: Mapped[str] = mapped_column(String(60))
    altitude_m: Mapped[int | None]
    harvest_year: Mapped[int]
    received_at: Mapped[date] = mapped_column(Date)
    received_kg: Mapped[Decimal] = mapped_column(Numeric(10, 3))
    notes: Mapped[str | None] = mapped_column(Text)
    roasts: Mapped[list["Roast"]] = relationship(
        back_populates="lot", order_by="Roast.roasted_at.desc()"
    )
    __table_args__ = (CheckConstraint("received_kg > 0", name="ck_lots_received_kg"),)


class Roast(Base, Timestamps):
    __tablename__ = "roasts"
    lot_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("green_lots.id", ondelete="RESTRICT"))
    roaster_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    roasted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    green_in_kg: Mapped[Decimal] = mapped_column(Numeric(10, 3))
    roasted_out_kg: Mapped[Decimal] = mapped_column(Numeric(10, 3))
    loss_pct: Mapped[Decimal] = mapped_column(Numeric(5, 2))
    duration_s: Mapped[int]
    drop_temp_c: Mapped[Decimal] = mapped_column(Numeric(5, 1))
    roast_level: Mapped[str] = mapped_column(String(10))
    notes: Mapped[str | None] = mapped_column(Text)
    lot: Mapped[GreenLot] = relationship(back_populates="roasts", lazy="joined")
    roaster: Mapped[User] = relationship(lazy="joined")

    @property
    def lot_code(self) -> str:
        return self.lot.code

    @property
    def roaster_name(self) -> str:
        return self.roaster.name

    __table_args__ = (
        CheckConstraint("green_in_kg > 0", name="ck_roasts_green_in"),
        CheckConstraint("roasted_out_kg > 0 AND roasted_out_kg <= green_in_kg", name="ck_roasts_out"),
        CheckConstraint("duration_s > 0", name="ck_roasts_duration"),
        CheckConstraint("roast_level IN ('light','medium','dark')", name="ck_roasts_level"),
        Index("ix_roasts_lot_id", "lot_id"),
        Index("ix_roasts_roasted_at", "roasted_at"),
    )
```

- [ ] **Step 6: Configurar Alembic**

`api/alembic.ini`:
```ini
[alembic]
script_location = %(here)s/alembic
```

`api/alembic/env.py`:
```python
from alembic import context
from sqlalchemy import engine_from_config, pool

from app import models  # noqa: F401  (registra las tablas en Base.metadata)
from app.config import settings
from app.db import Base

config = context.config
config.set_main_option("sqlalchemy.url", settings.database_url.replace("%", "%%"))

connectable = engine_from_config(
    config.get_section(config.config_ini_section), prefix="sqlalchemy.", poolclass=pool.NullPool
)
with connectable.connect() as connection:
    context.configure(connection=connection, target_metadata=Base.metadata)
    with context.begin_transaction():
        context.run_migrations()
```

`api/alembic/script.py.mako`:
```mako
"""${message}

Revision ID: ${up_revision}
Revises: ${down_revision | comma,n}
Create Date: ${create_date}
"""
from alembic import op
import sqlalchemy as sa
${imports if imports else ""}

revision = ${repr(up_revision)}
down_revision = ${repr(down_revision)}
branch_labels = ${repr(branch_labels)}
depends_on = ${repr(depends_on)}


def upgrade() -> None:
    ${upgrades if upgrades else "pass"}


def downgrade() -> None:
    ${downgrades if downgrades else "pass"}
```

- [ ] **Step 7: Generar la migración inicial y revisarla**

```bash
cd api && mkdir -p alembic/versions
export DATABASE_URL=postgresql+psycopg://postgres:test@localhost:55432/brewtrack_test
export JWT_SECRET=test-secret-test-secret-test-secret
alembic revision --autogenerate -m "initial schema" --rev-id 0001
```
Expected: crea `alembic/versions/0001_initial_schema.py`. Abrirlo y comprobar que tiene las 3 tablas, los `CheckConstraint` (`ck_users_role`, `ck_lots_received_kg`, `ck_roasts_*`), la FK con `ondelete='RESTRICT'` y los dos índices `ix_roasts_*`. Si falta algo, corregir el modelo y regenerar (borrar el archivo primero).

- [ ] **Step 8: Verificar que pasan**

Run: `cd api && pytest -v`
Expected: 6 passed (2 health + 4 models).

- [ ] **Step 9: Commit**

```bash
cd /Users/federicopizarro/Desktop/3
git add api
git commit -m "feat(api): models and initial alembic migration"
```

---

### Task 3: Auth (hash, JWT, login/refresh/me, CLI create-admin)

**Files:**
- Create: `api/app/security.py`, `api/app/deps.py`, `api/app/schemas.py`, `api/app/routers/__init__.py`, `api/app/routers/auth.py`, `api/app/cli.py`
- Modify: `api/app/main.py`, `api/tests/conftest.py`
- Test: `api/tests/test_auth.py`, `api/tests/test_cli.py`

**Interfaces:**
- Consumes: `User`, `get_db`, `ApiError`, `settings`.
- Produces: `hash_password(p) -> str`, `verify_password(p, h) -> bool`, `create_access_token(user_id) -> str`, `create_refresh_token(user_id) -> str`, `decode_token(token, kind) -> UUID | None` (`kind` = `"access"`/`"refresh"`); `deps.current_user` (401 si falta/inválido/inactivo), `deps.admin_only` (403); `schemas.UserOut`, `schemas.Num`, `schemas.ORM`; `cli.create_admin(email, name, password) -> User` (ValueError); fixtures `make_user(email, role, active, password)`, `auth(user) -> headers`, `roaster`, `admin`.

- [ ] **Step 1: Agregar fixtures a `api/tests/conftest.py`**

Añadir al bloque de imports: `from app.models import User` y `from app.security import create_access_token, hash_password`. Añadir al final:

```python
@pytest.fixture
def make_user(db):
    def _make(email="roaster@x.com", role="roaster", active=True, password="secret123"):
        u = User(
            email=email, name=email.split("@")[0], role=role, active=active,
            password_hash=hash_password(password),
        )
        db.add(u)
        db.commit()
        db.refresh(u)
        return u

    return _make


@pytest.fixture
def auth():
    def _auth(user):
        return {"Authorization": f"Bearer {create_access_token(user.id)}"}

    return _auth


@pytest.fixture
def roaster(make_user):
    return make_user("roaster@x.com", "roaster")


@pytest.fixture
def admin(make_user):
    return make_user("admin@x.com", "admin")
```

- [ ] **Step 2: Escribir los tests que fallan**

`api/tests/test_auth.py`:
```python
from app.security import create_access_token

ME = "/api/v1/auth/me"


def login(client, email="roaster@x.com", password="secret123"):
    return client.post("/api/v1/auth/login", json={"email": email, "password": password})


def test_login_ok(client, roaster):
    r = login(client)
    assert r.status_code == 200
    assert {"access_token", "refresh_token"} <= r.json().keys()


def test_login_email_is_case_insensitive(client, roaster):
    assert login(client, "ROASTER@X.COM").status_code == 200


def test_login_wrong_password(client, roaster):
    r = login(client, password="nope")
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "invalid_credentials"


def test_login_inactive_user(client, make_user):
    make_user("off@x.com", active=False)
    assert login(client, "off@x.com").status_code == 401


def test_me(client, roaster, auth):
    r = client.get(ME, headers=auth(roaster))
    assert r.status_code == 200
    assert r.json()["email"] == "roaster@x.com" and r.json()["role"] == "roaster"
    assert "password_hash" not in r.json()


def test_me_requires_token(client):
    r = client.get(ME)
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "unauthorized"


def test_refresh_token_is_not_an_access_token(client, roaster):
    tokens = login(client).json()
    r = client.get(ME, headers={"Authorization": f"Bearer {tokens['refresh_token']}"})
    assert r.status_code == 401


def test_access_token_is_not_a_refresh_token(client, roaster):
    r = client.post("/api/v1/auth/refresh", json={"refresh_token": create_access_token(roaster.id)})
    assert r.status_code == 401


def test_refresh_returns_working_access_token(client, roaster):
    tokens = login(client).json()
    r = client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert r.status_code == 200
    r2 = client.get(ME, headers={"Authorization": f"Bearer {r.json()['access_token']}"})
    assert r2.status_code == 200


def test_token_of_deactivated_user_is_rejected(client, db, roaster, auth):
    headers = auth(roaster)
    roaster.active = False
    db.commit()
    assert client.get(ME, headers=headers).status_code == 401
```

`api/tests/test_cli.py`:
```python
import pytest

from app.cli import create_admin


def test_create_admin():
    u = create_admin("Boss@X.com", "Boss", "longenough1")
    assert u.role == "admin" and u.email == "boss@x.com" and u.password_hash != "longenough1"


def test_create_admin_rejects_short_password():
    with pytest.raises(ValueError):
        create_admin("a@x.com", "A", "short")


def test_create_admin_rejects_duplicate_email():
    create_admin("a@x.com", "A", "longenough1")
    with pytest.raises(ValueError):
        create_admin("A@x.com", "A2", "longenough1")
```

- [ ] **Step 3: Verificar que fallan**

Run: `cd api && pytest tests/test_auth.py tests/test_cli.py -v`
Expected: ERROR (`app.security` no existe).

- [ ] **Step 4: Implementar**

`api/app/security.py`:
```python
import uuid
from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError

from app.config import settings

_ph = PasswordHasher()


def hash_password(password: str) -> str:
    return _ph.hash(password)


def verify_password(password: str, hashed: str) -> bool:
    try:
        return _ph.verify(hashed, password)
    except (VerifyMismatchError, InvalidHashError):
        return False


def _token(user_id: uuid.UUID, kind: str, ttl: timedelta) -> str:
    now = datetime.now(timezone.utc)
    claims = {"sub": str(user_id), "typ": kind, "iat": now, "exp": now + ttl}
    return jwt.encode(claims, settings.jwt_secret, algorithm="HS256")


def create_access_token(user_id: uuid.UUID) -> str:
    return _token(user_id, "access", timedelta(minutes=settings.access_ttl_min))


def create_refresh_token(user_id: uuid.UUID) -> str:
    return _token(user_id, "refresh", timedelta(days=settings.refresh_ttl_days))


def decode_token(token: str, kind: str) -> uuid.UUID | None:
    try:
        data = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
        if data.get("typ") != kind:
            return None
        return uuid.UUID(data["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        return None
```

`api/app/deps.py`:
```python
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.db import get_db
from app.errors import ApiError
from app.models import User
from app.security import decode_token

_bearer = HTTPBearer(auto_error=False)


def current_user(
    cred: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    uid = decode_token(cred.credentials, "access") if cred else None
    user = db.get(User, uid) if uid else None
    if user is None or not user.active:
        raise ApiError(401, "unauthorized", "Credenciales inválidas o ausentes")
    return user


def admin_only(user: User = Depends(current_user)) -> User:
    if user.role != "admin":
        raise ApiError(403, "forbidden", "Requiere rol admin")
    return user
```

`api/app/schemas.py`:
```python
import uuid
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, PlainSerializer

# Decimal en BD, número JSON hacia el cliente.
Num = Annotated[Decimal, PlainSerializer(float, return_type=float, when_used="json")]


class ORM(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class UserOut(ORM):
    id: uuid.UUID
    email: str
    name: str
    role: Literal["roaster", "admin"]
    active: bool
```

`api/app/routers/__init__.py`: archivo vacío.

`api/app/routers/auth.py`:
```python
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import current_user
from app.errors import ApiError
from app.models import User
from app.schemas import UserOut
from app.security import (
    create_access_token, create_refresh_token, decode_token, verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])


class LoginIn(BaseModel):
    email: str
    password: str


class RefreshIn(BaseModel):
    refresh_token: str


class Tokens(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class AccessOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


@router.post("/login", response_model=Tokens)
def login(body: LoginIn, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == body.email.strip().lower()))
    if not user or not user.active or not verify_password(body.password, user.password_hash):
        raise ApiError(401, "invalid_credentials", "Email o contraseña incorrectos")
    return Tokens(
        access_token=create_access_token(user.id), refresh_token=create_refresh_token(user.id)
    )


@router.post("/refresh", response_model=AccessOut)
def refresh(body: RefreshIn, db: Session = Depends(get_db)):
    uid = decode_token(body.refresh_token, "refresh")
    user = db.get(User, uid) if uid else None
    if not user or not user.active:
        raise ApiError(401, "unauthorized", "Refresh token inválido")
    return AccessOut(access_token=create_access_token(user.id))


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(current_user)):
    return user
```

`api/app/cli.py`:
```python
import argparse
import getpass
import sys

from sqlalchemy import select

from app.db import SessionLocal
from app.models import User
from app.security import hash_password


def create_admin(email: str, name: str, password: str) -> User:
    if len(password) < 8:
        raise ValueError("La contraseña debe tener al menos 8 caracteres")
    with SessionLocal() as db:
        if db.scalar(select(User).where(User.email == email.lower())):
            raise ValueError("Ya existe un usuario con ese email")
        user = User(
            email=email.lower(), name=name, role="admin", password_hash=hash_password(password)
        )
        db.add(user)
        db.commit()
        return user


def main() -> None:
    p = argparse.ArgumentParser(prog="python -m app.cli")
    p.add_argument("command", choices=["create-admin"])
    p.add_argument("--email", required=True)
    p.add_argument("--name", default="Admin")
    a = p.parse_args()
    try:
        create_admin(a.email, a.name, getpass.getpass("Contraseña: "))
    except ValueError as e:
        sys.exit(str(e))
    print("Admin creado")


if __name__ == "__main__":
    main()
```

Modificar `api/app/main.py`: tras `app.add_middleware(...)` y antes de `health`, añadir `from app.routers import auth` al bloque de imports y:
```python
app.include_router(auth.router, prefix="/api/v1")
```

- [ ] **Step 5: Verificar que pasan**

Run: `cd api && pytest -v`
Expected: todos pasan (6 anteriores + 10 auth + 3 cli).

- [ ] **Step 6: Commit**

```bash
cd /Users/federicopizarro/Desktop/3
git add api
git commit -m "feat(api): auth with argon2, JWT access/refresh, roles and create-admin CLI"
```

---

### Task 4: Endpoints de usuarios (solo admin)

**Files:**
- Create: `api/app/routers/users.py`
- Modify: `api/app/main.py`
- Test: `api/tests/test_users.py`

**Interfaces:**
- Consumes: `admin_only`, `UserOut`, `hash_password`, `commit_or_409`, fixtures `make_user`, `auth`, `roaster`, `admin`.
- Produces: `GET /api/v1/users -> list[UserOut]`, `POST /api/v1/users` (201), `PATCH /api/v1/users/{id}`.

- [ ] **Step 1: Escribir los tests que fallan**

`api/tests/test_users.py`:
```python
URL = "/api/v1/users"


def _new(**kw):
    return {"email": "new@x.com", "name": "New", "password": "longenough1", "role": "roaster", **kw}


def test_only_admin_can_list(client, roaster, admin, auth):
    assert client.get(URL).status_code == 401
    assert client.get(URL, headers=auth(roaster)).status_code == 403
    r = client.get(URL, headers=auth(admin))
    assert r.status_code == 200 and len(r.json()) == 2


def test_create_user_and_login(client, admin, auth):
    r = client.post(URL, json=_new(email="New@X.com"), headers=auth(admin))
    assert r.status_code == 201 and r.json()["email"] == "new@x.com" and r.json()["active"] is True
    login = client.post("/api/v1/auth/login", json={"email": "new@x.com", "password": "longenough1"})
    assert login.status_code == 200


def test_create_duplicate_email_is_409(client, admin, auth):
    client.post(URL, json=_new(), headers=auth(admin))
    r = client.post(URL, json=_new(), headers=auth(admin))
    assert r.status_code == 409 and r.json()["error"]["code"] == "duplicate_email"


def test_create_validates_input(client, admin, auth):
    assert client.post(URL, json=_new(password="short"), headers=auth(admin)).status_code == 422
    assert client.post(URL, json=_new(role="boss"), headers=auth(admin)).status_code == 422
    assert client.post(URL, json=_new(email="not-an-email"), headers=auth(admin)).status_code == 422


def test_patch_user(client, admin, roaster, auth):
    r = client.patch(
        f"{URL}/{roaster.id}", json={"name": "Renamed", "password": "anotherpass1"}, headers=auth(admin)
    )
    assert r.status_code == 200 and r.json()["name"] == "Renamed"
    login = client.post("/api/v1/auth/login", json={"email": "roaster@x.com", "password": "anotherpass1"})
    assert login.status_code == 200


def test_patch_null_is_rejected(client, admin, roaster, auth):
    assert client.patch(f"{URL}/{roaster.id}", json={"name": None}, headers=auth(admin)).status_code == 422


def test_cannot_deactivate_or_demote_last_admin(client, admin, make_user, auth):
    url = f"{URL}/{admin.id}"
    r = client.patch(url, json={"active": False}, headers=auth(admin))
    assert r.status_code == 409 and r.json()["error"]["code"] == "last_admin"
    assert client.patch(url, json={"role": "roaster"}, headers=auth(admin)).status_code == 409
    make_user("admin2@x.com", "admin")
    assert client.patch(url, json={"active": False}, headers=auth(admin)).status_code == 200
```

- [ ] **Step 2: Verificar que fallan**

Run: `cd api && pytest tests/test_users.py -v`
Expected: FAIL (404 en `/api/v1/users`).

- [ ] **Step 3: Implementar**

`api/app/routers/users.py`:
```python
import uuid
from typing import Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import admin_only
from app.errors import ApiError, commit_or_409
from app.models import User
from app.schemas import UserOut
from app.security import hash_password

router = APIRouter(prefix="/users", tags=["users"], dependencies=[Depends(admin_only)])

Role = Literal["roaster", "admin"]


class UserIn(BaseModel):
    email: EmailStr
    name: str = Field(min_length=1, max_length=120)
    password: str = Field(min_length=8, max_length=128)
    role: Role


class UserPatch(BaseModel):
    # default=None sin "| None": omitir el campo lo ignora, enviar null es 422.
    name: str = Field(default=None, min_length=1, max_length=120)
    password: str = Field(default=None, min_length=8, max_length=128)
    role: Role = None
    active: bool = None


@router.get("", response_model=list[UserOut])
def list_users(db: Session = Depends(get_db)):
    return db.scalars(select(User).order_by(User.email)).all()


@router.post("", response_model=UserOut, status_code=201)
def create_user(body: UserIn, db: Session = Depends(get_db)):
    user = User(
        email=body.email.lower(), name=body.name, role=body.role,
        password_hash=hash_password(body.password),
    )
    db.add(user)
    commit_or_409(db, "duplicate_email", "Ya existe un usuario con ese email")
    return user


@router.patch("/{user_id}", response_model=UserOut)
def patch_user(user_id: uuid.UUID, body: UserPatch, db: Session = Depends(get_db)):
    user = db.get(User, user_id)
    if not user:
        raise ApiError(404, "not_found", "Usuario no encontrado")
    changes = body.model_dump(exclude_unset=True)
    demoting = changes.get("active") is False or changes.get("role") == "roaster"
    if user.role == "admin" and user.active and demoting:
        admins = db.scalar(
            select(func.count()).select_from(User).where(User.role == "admin", User.active)
        )
        if admins <= 1:
            raise ApiError(409, "last_admin", "No se puede desactivar o degradar al último admin")
    if "password" in changes:
        user.password_hash = hash_password(changes.pop("password"))
    for k, v in changes.items():
        setattr(user, k, v)
    db.commit()
    return user
```

Modificar `api/app/main.py`: importar `users` junto a `auth` (`from app.routers import auth, users`) y añadir `app.include_router(users.router, prefix="/api/v1")` tras el de auth.

- [ ] **Step 4: Verificar que pasan**

Run: `cd api && pytest -v`
Expected: todos pasan.

- [ ] **Step 5: Commit**

```bash
cd /Users/federicopizarro/Desktop/3
git add api
git commit -m "feat(api): admin-only user management with last-admin guard"
```

---

### Task 5: Endpoints de lotes de café verde (con stock calculado)

**Files:**
- Create: `api/app/stock.py`, `api/app/routers/green_lots.py`
- Modify: `api/app/schemas.py`, `api/app/main.py`, `api/tests/conftest.py`
- Test: `api/tests/test_green_lots.py`

**Interfaces:**
- Consumes: `current_user`, `admin_only`, `GreenLot`, `Roast`, `commit_or_409`, `Num`, `ORM`.
- Produces: `stock.used_kg(db, lot_id, exclude_roast_id=None) -> Decimal`; `stock.used_expr()` (subconsulta escalar correlacionada con `GreenLot`); `schemas.Page[T]`, `schemas.LotOut` (incluye `stock_kg`), `schemas.RoastOut` (incluye `lot_code`, `roaster_name`, `loss_pct`), `schemas.LotDetail` (`LotOut` + `roasts`); fixtures `make_lot(code, kg, **overrides)` y `make_roast(lot, user, green_in, out, **overrides)`. Endpoints: `GET /green-lots` (`country`, `process`, `limit`, `offset` → `Page[LotOut]`), `GET /green-lots/{id}` → `LotDetail`, `POST` (201), `PATCH`, `DELETE` (admin, 204).

- [ ] **Step 1: Agregar fixtures a `api/tests/conftest.py`**

Añadir a los imports: `from datetime import date, datetime, timezone`, `from decimal import Decimal`, y ampliar `from app.models import User` a `from app.models import GreenLot, Roast, User`. Añadir al final:

```python
@pytest.fixture
def make_lot(db):
    def _make(code="GL-1", kg="60", **kw):
        data = dict(
            code=code, origin_country="Colombia", variety="Caturra", process="washed",
            harvest_year=2026, received_at=date(2026, 1, 1), received_kg=Decimal(kg),
        )
        lot = GreenLot(**{**data, **kw})
        db.add(lot)
        db.commit()
        db.refresh(lot)
        return lot

    return _make


@pytest.fixture
def make_roast(db):
    def _make(lot, user, green_in="10", out="8.5", **kw):
        data = dict(
            lot_id=lot.id, roaster_id=user.id, roasted_at=datetime(2026, 2, 1, tzinfo=timezone.utc),
            green_in_kg=Decimal(green_in), roasted_out_kg=Decimal(out), loss_pct=Decimal("15.00"),
            duration_s=600, drop_temp_c=Decimal("205.0"), roast_level="medium",
        )
        roast = Roast(**{**data, **kw})
        db.add(roast)
        db.commit()
        db.refresh(roast)
        return roast

    return _make
```

- [ ] **Step 2: Escribir los tests que fallan**

`api/tests/test_green_lots.py`:
```python
import uuid

URL = "/api/v1/green-lots"


def _body(**kw):
    return {
        "code": "GL-2026-001", "origin_country": "Colombia", "variety": "Caturra",
        "process": "washed", "harvest_year": 2026, "received_at": "2026-01-15",
        "received_kg": 69, **kw,
    }


def test_requires_auth(client):
    assert client.get(URL).status_code == 401


def test_create_lot(client, roaster, auth):
    r = client.post(URL, json=_body(), headers=auth(roaster))
    assert r.status_code == 201
    assert r.json()["stock_kg"] == 69.0 and r.json()["received_kg"] == 69.0


def test_duplicate_code_is_409(client, roaster, auth):
    client.post(URL, json=_body(), headers=auth(roaster))
    r = client.post(URL, json=_body(), headers=auth(roaster))
    assert r.status_code == 409 and r.json()["error"]["code"] == "duplicate_code"


def test_validation(client, roaster, auth):
    r = client.post(URL, json=_body(received_kg=0), headers=auth(roaster))
    assert r.status_code == 422 and r.json()["error"]["code"] == "validation_error"


def test_detail_has_stock_and_roasts(client, roaster, auth, make_lot, make_roast):
    lot = make_lot(kg="60")
    make_roast(lot, roaster, green_in="10", out="8.5")
    d = client.get(f"{URL}/{lot.id}", headers=auth(roaster)).json()
    assert d["stock_kg"] == 50.0
    assert len(d["roasts"]) == 1 and d["roasts"][0]["lot_code"] == "GL-1"
    assert d["roasts"][0]["roaster_name"] == "roaster"


def test_unknown_lot_is_404(client, roaster, auth):
    r = client.get(f"{URL}/{uuid.uuid4()}", headers=auth(roaster))
    assert r.status_code == 404 and r.json()["error"]["code"] == "not_found"


def test_list_filters_and_pagination(client, roaster, auth, make_lot):
    make_lot("GL-1")
    make_lot("GL-2", origin_country="Kenya", process="natural")
    make_lot("GL-3")
    h = auth(roaster)
    assert client.get(f"{URL}?country=colom", headers=h).json()["total"] == 2
    assert client.get(f"{URL}?process=NAT", headers=h).json()["total"] == 1
    page = client.get(f"{URL}?limit=1&offset=1", headers=h).json()
    assert len(page["items"]) == 1 and page["total"] == 3 and page["limit"] == 1


def test_patch_lot(client, roaster, auth, make_lot):
    lot = make_lot()
    r = client.patch(f"{URL}/{lot.id}", json={"notes": "dulce", "region": None}, headers=auth(roaster))
    assert r.status_code == 200 and r.json()["notes"] == "dulce"
    assert client.patch(f"{URL}/{lot.id}", json={"code": None}, headers=auth(roaster)).status_code == 422


def test_cannot_lower_received_kg_below_roasted(client, roaster, auth, make_lot, make_roast):
    lot = make_lot(kg="60")
    make_roast(lot, roaster, green_in="10", out="8.5")
    url = f"{URL}/{lot.id}"
    r = client.patch(url, json={"received_kg": 9.999}, headers=auth(roaster))
    assert r.status_code == 409 and r.json()["error"]["code"] == "insufficient_stock"
    r = client.patch(url, json={"received_kg": 10}, headers=auth(roaster))
    assert r.status_code == 200 and r.json()["stock_kg"] == 0.0


def test_delete_rules(client, roaster, admin, auth, make_lot, make_roast):
    with_roasts, empty = make_lot("GL-1"), make_lot("GL-2")
    make_roast(with_roasts, roaster)
    assert client.delete(f"{URL}/{empty.id}", headers=auth(roaster)).status_code == 403
    r = client.delete(f"{URL}/{with_roasts.id}", headers=auth(admin))
    assert r.status_code == 409 and r.json()["error"]["code"] == "lot_has_roasts"
    assert client.delete(f"{URL}/{empty.id}", headers=auth(admin)).status_code == 204
    assert client.get(f"{URL}/{empty.id}", headers=auth(admin)).status_code == 404
```

- [ ] **Step 3: Verificar que fallan**

Run: `cd api && pytest tests/test_green_lots.py -v`
Expected: FAIL (404 en `/api/v1/green-lots`).

- [ ] **Step 4: Implementar**

`api/app/stock.py`:
```python
import uuid
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import GreenLot, Roast


def used_expr():
    """Kg ya tostados del lote, como subconsulta correlacionada con GreenLot."""
    return (
        select(func.coalesce(func.sum(Roast.green_in_kg), 0))
        .where(Roast.lot_id == GreenLot.id)
        .correlate(GreenLot)
        .scalar_subquery()
    )


def used_kg(db: Session, lot_id: uuid.UUID, exclude_roast_id: uuid.UUID | None = None) -> Decimal:
    q = select(func.coalesce(func.sum(Roast.green_in_kg), 0)).where(Roast.lot_id == lot_id)
    if exclude_roast_id:
        q = q.where(Roast.id != exclude_roast_id)
    return db.scalar(q)
```

Reemplazar el bloque de imports de `api/app/schemas.py` y añadir los modelos al final. El archivo queda:
```python
import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Annotated, Generic, Literal, TypeVar

from pydantic import BaseModel, ConfigDict, PlainSerializer

# Decimal en BD, número JSON hacia el cliente.
Num = Annotated[Decimal, PlainSerializer(float, return_type=float, when_used="json")]
T = TypeVar("T")


class ORM(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class Page(BaseModel, Generic[T]):
    items: list[T]
    total: int
    limit: int
    offset: int


class UserOut(ORM):
    id: uuid.UUID
    email: str
    name: str
    role: Literal["roaster", "admin"]
    active: bool


class LotOut(ORM):
    id: uuid.UUID
    code: str
    origin_country: str
    region: str | None
    farm: str | None
    producer: str | None
    variety: str
    process: str
    altitude_m: int | None
    harvest_year: int
    received_at: date
    received_kg: Num
    notes: str | None
    stock_kg: Num  # se asigna como atributo transitorio antes de serializar


class RoastOut(ORM):
    id: uuid.UUID
    lot_id: uuid.UUID
    lot_code: str
    roaster_id: uuid.UUID
    roaster_name: str
    roasted_at: datetime
    green_in_kg: Num
    roasted_out_kg: Num
    loss_pct: Num
    duration_s: int
    drop_temp_c: Num
    roast_level: Literal["light", "medium", "dark"]
    notes: str | None


class LotDetail(LotOut):
    roasts: list[RoastOut]
```

`api/app/routers/green_lots.py`:
```python
import uuid
from datetime import date
from decimal import Decimal

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy import exists, func, select
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import admin_only, current_user
from app.errors import ApiError, commit_or_409
from app.models import GreenLot, Roast
from app.schemas import LotDetail, LotOut, Page
from app.stock import used_expr, used_kg

router = APIRouter(prefix="/green-lots", tags=["green-lots"], dependencies=[Depends(current_user)])


class LotIn(BaseModel):
    code: str = Field(min_length=1, max_length=40)
    origin_country: str = Field(min_length=1, max_length=80)
    region: str | None = Field(None, max_length=120)
    farm: str | None = Field(None, max_length=120)
    producer: str | None = Field(None, max_length=120)
    variety: str = Field(min_length=1, max_length=120)
    process: str = Field(min_length=1, max_length=60)
    altitude_m: int | None = Field(None, gt=0, le=6000)
    harvest_year: int = Field(ge=1900, le=2100)
    received_at: date
    received_kg: Decimal = Field(gt=0, max_digits=10, decimal_places=3)
    notes: str | None = None


class LotPatch(BaseModel):
    # Campos obligatorios: default=None sin "| None" (omitir = ignorar, null = 422).
    code: str = Field(default=None, min_length=1, max_length=40)
    origin_country: str = Field(default=None, min_length=1, max_length=80)
    region: str | None = Field(None, max_length=120)
    farm: str | None = Field(None, max_length=120)
    producer: str | None = Field(None, max_length=120)
    variety: str = Field(default=None, min_length=1, max_length=120)
    process: str = Field(default=None, min_length=1, max_length=60)
    altitude_m: int | None = Field(None, gt=0, le=6000)
    harvest_year: int = Field(default=None, ge=1900, le=2100)
    received_at: date = None
    received_kg: Decimal = Field(default=None, gt=0, max_digits=10, decimal_places=3)
    notes: str | None = None


def _lot_or_404(db: Session, lot_id: uuid.UUID, lock: bool = False) -> GreenLot:
    lot = db.get(GreenLot, lot_id, with_for_update=lock or None)
    if not lot:
        raise ApiError(404, "not_found", "Lote no encontrado")
    return lot


def _with_stock(db: Session, lot: GreenLot) -> GreenLot:
    lot.stock_kg = lot.received_kg - used_kg(db, lot.id)
    return lot


@router.get("", response_model=Page[LotOut])
def list_lots(
    country: str | None = None,
    process: str | None = None,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    where = []
    if country:
        where.append(GreenLot.origin_country.ilike(f"%{country}%"))
    if process:
        where.append(GreenLot.process.ilike(f"%{process}%"))
    stock = (GreenLot.received_kg - used_expr()).label("stock_kg")
    rows = db.execute(
        select(GreenLot, stock).where(*where)
        .order_by(GreenLot.received_at.desc(), GreenLot.code).limit(limit).offset(offset)
    ).all()
    for lot, s in rows:
        lot.stock_kg = s
    total = db.scalar(select(func.count()).select_from(GreenLot).where(*where))
    return Page[LotOut](
        items=[LotOut.model_validate(lot) for lot, _ in rows], total=total, limit=limit, offset=offset
    )


@router.get("/{lot_id}", response_model=LotDetail)
def get_lot(lot_id: uuid.UUID, db: Session = Depends(get_db)):
    return _with_stock(db, _lot_or_404(db, lot_id))


@router.post("", response_model=LotOut, status_code=201)
def create_lot(body: LotIn, db: Session = Depends(get_db)):
    lot = GreenLot(**body.model_dump())
    db.add(lot)
    commit_or_409(db, "duplicate_code", "Ya existe un lote con ese código")
    lot.stock_kg = lot.received_kg
    return lot


@router.patch("/{lot_id}", response_model=LotOut)
def patch_lot(lot_id: uuid.UUID, body: LotPatch, db: Session = Depends(get_db)):
    lot = _lot_or_404(db, lot_id, lock=True)
    changes = body.model_dump(exclude_unset=True)
    if "received_kg" in changes and changes["received_kg"] < used_kg(db, lot.id):
        raise ApiError(409, "insufficient_stock", "received_kg es menor que lo ya tostado")
    for k, v in changes.items():
        setattr(lot, k, v)
    commit_or_409(db, "duplicate_code", "Ya existe un lote con ese código")
    return _with_stock(db, lot)


@router.delete("/{lot_id}", status_code=204, dependencies=[Depends(admin_only)])
def delete_lot(lot_id: uuid.UUID, db: Session = Depends(get_db)):
    lot = _lot_or_404(db, lot_id)
    if db.scalar(select(exists().where(Roast.lot_id == lot.id))):
        raise ApiError(409, "lot_has_roasts", "El lote tiene tuestes y no se puede borrar")
    db.delete(lot)
    db.commit()
```

Modificar `api/app/main.py`: importar `green_lots` (`from app.routers import auth, green_lots, users`) y añadir `app.include_router(green_lots.router, prefix="/api/v1")`.

- [ ] **Step 5: Verificar que pasan**

Run: `cd api && pytest -v`
Expected: todos pasan. Si `test_delete_rules` falla porque SQLAlchemy intenta anular `lot_id` al borrar, revisar que el 409 se lance antes de `db.delete` (el chequeo `exists` va primero).

- [ ] **Step 6: Commit**

```bash
cd /Users/federicopizarro/Desktop/3
git add api
git commit -m "feat(api): green lots with computed stock, filters and pagination"
```

---

### Task 6: Endpoints de tuestes (validación de stock y merma)

**Files:**
- Create: `api/app/routers/roasts.py`
- Modify: `api/app/schemas.py`, `api/app/main.py`
- Test: `api/tests/test_roasts.py`

**Interfaces:**
- Consumes: `used_kg`, `LotOut`, `RoastOut`, `Page`, fixtures `make_lot`, `make_roast`, `make_user`.
- Produces: `schemas.RoastDetail` (`RoastOut` + `lot: LotOut`); `GET /roasts` (`lot_id`, `level`, `date_from`, `date_to`, `limit`, `offset` → `Page[RoastOut]`), `GET /roasts/{id}` → `RoastDetail`, `POST /roasts` (201), `PATCH /roasts/{id}`, `DELETE /roasts/{id}` (admin, 204). `loss_pct` se calcula en servidor y se redondea a 2 decimales.

- [ ] **Step 1: Escribir los tests que fallan**

`api/tests/test_roasts.py`:
```python
import uuid

URL = "/api/v1/roasts"
LOTS = "/api/v1/green-lots"


def _body(lot, **kw):
    return {
        "lot_id": str(lot.id), "roasted_at": "2026-02-01T10:00:00Z", "green_in_kg": 10,
        "roasted_out_kg": 8.5, "duration_s": 600, "drop_temp_c": 205.0, "roast_level": "medium", **kw,
    }


def test_create_roast_computes_loss_and_reduces_stock(client, roaster, auth, make_lot):
    lot = make_lot(kg="60")
    r = client.post(URL, json=_body(lot), headers=auth(roaster))
    assert r.status_code == 201
    b = r.json()
    assert b["loss_pct"] == 15.0 and b["lot_code"] == "GL-1"
    assert b["roaster_name"] == "roaster" and b["roaster_id"] == str(roaster.id)
    assert client.get(f"{LOTS}/{lot.id}", headers=auth(roaster)).json()["stock_kg"] == 50.0


def test_requires_auth(client):
    assert client.get(URL).status_code == 401


def test_roast_cannot_exceed_stock(client, roaster, auth, make_lot):
    lot = make_lot(kg="5")
    r = client.post(URL, json=_body(lot), headers=auth(roaster))
    assert r.status_code == 409 and r.json()["error"]["code"] == "insufficient_stock"


def test_roast_may_consume_exactly_the_remaining_stock(client, roaster, auth, make_lot):
    lot = make_lot(kg="10")
    ok = client.post(URL, json=_body(lot, roasted_out_kg=9), headers=auth(roaster))
    assert ok.status_code == 201
    assert client.get(f"{LOTS}/{lot.id}", headers=auth(roaster)).json()["stock_kg"] == 0.0
    over = client.post(URL, json=_body(lot, green_in_kg=0.001, roasted_out_kg=0.001), headers=auth(roaster))
    assert over.status_code == 409


def test_out_cannot_exceed_in(client, roaster, auth, make_lot):
    r = client.post(URL, json=_body(make_lot(), roasted_out_kg=11), headers=auth(roaster))
    assert r.status_code == 422 and r.json()["error"]["code"] == "validation_error"


def test_invalid_level_is_422(client, roaster, auth, make_lot):
    r = client.post(URL, json=_body(make_lot(), roast_level="burnt"), headers=auth(roaster))
    assert r.status_code == 422


def test_unknown_lot_is_404(client, roaster, auth, make_lot):
    lot = make_lot()
    r = client.post(URL, json=_body(lot, lot_id=str(uuid.uuid4())), headers=auth(roaster))
    assert r.status_code == 404 and r.json()["error"]["code"] == "lot_not_found"


def test_detail_includes_origin_lot(client, roaster, auth, make_lot, make_roast):
    lot = make_lot()
    roast = make_roast(lot, roaster)
    d = client.get(f"{URL}/{roast.id}", headers=auth(roaster)).json()
    assert d["lot"]["code"] == "GL-1" and d["lot"]["origin_country"] == "Colombia"
    assert d["lot"]["stock_kg"] == 50.0


def test_patch_permissions_and_rules(client, roaster, admin, make_user, auth, make_lot, make_roast):
    lot = make_lot(kg="20")
    roast = make_roast(lot, roaster, green_in="10", out="8.5")
    other = make_user("other@x.com", "roaster")
    url = f"{URL}/{roast.id}"
    assert client.patch(url, json={"notes": "x"}, headers=auth(other)).status_code == 403
    r = client.patch(url, json={"roasted_out_kg": 8}, headers=auth(roaster))
    assert r.status_code == 200 and r.json()["loss_pct"] == 20.0
    # el stock exacto del lote (20) es válido porque se excluye el propio tueste
    assert client.patch(url, json={"green_in_kg": 20}, headers=auth(admin)).status_code == 200
    assert client.patch(url, json={"green_in_kg": 20.001}, headers=auth(admin)).status_code == 409
    assert client.patch(url, json={"roasted_out_kg": 30}, headers=auth(admin)).status_code == 422


def test_delete_is_admin_only_and_restores_stock(client, roaster, admin, auth, make_lot, make_roast):
    lot = make_lot(kg="60")
    roast = make_roast(lot, roaster, green_in="10")
    assert client.delete(f"{URL}/{roast.id}", headers=auth(roaster)).status_code == 403
    assert client.delete(f"{URL}/{roast.id}", headers=auth(admin)).status_code == 204
    assert client.get(f"{LOTS}/{lot.id}", headers=auth(admin)).json()["stock_kg"] == 60.0


def test_list_filters(client, roaster, auth, make_lot, make_roast):
    a, b = make_lot("GL-1"), make_lot("GL-2")
    make_roast(a, roaster, roast_level="light")
    make_roast(b, roaster, roast_level="dark")
    h = auth(roaster)
    assert client.get(f"{URL}?level=dark", headers=h).json()["total"] == 1
    assert client.get(f"{URL}?lot_id={a.id}", headers=h).json()["items"][0]["lot_code"] == "GL-1"
    assert client.get(f"{URL}?date_from=2026-02-01&date_to=2026-02-01", headers=h).json()["total"] == 2
    assert client.get(f"{URL}?date_from=2026-02-02", headers=h).json()["total"] == 0
    assert client.get(f"{URL}?limit=1", headers=h).json()["total"] == 2
```

- [ ] **Step 2: Verificar que fallan**

Run: `cd api && pytest tests/test_roasts.py -v`
Expected: FAIL (404 en `/api/v1/roasts`).

- [ ] **Step 3: Implementar**

Añadir al final de `api/app/schemas.py`:
```python
class RoastDetail(RoastOut):
    lot: LotOut
```

`api/app/routers/roasts.py`:
```python
import uuid
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal
from typing import Literal

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field, model_validator
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import admin_only, current_user
from app.errors import ApiError
from app.models import GreenLot, Roast, User
from app.schemas import Page, RoastDetail, RoastOut
from app.stock import used_kg

router = APIRouter(prefix="/roasts", tags=["roasts"], dependencies=[Depends(current_user)])

RoastLevel = Literal["light", "medium", "dark"]
Kg = dict(gt=0, max_digits=10, decimal_places=3)


class RoastIn(BaseModel):
    lot_id: uuid.UUID
    roasted_at: datetime
    green_in_kg: Decimal = Field(**Kg)
    roasted_out_kg: Decimal = Field(**Kg)
    duration_s: int = Field(gt=0, le=7200)
    drop_temp_c: Decimal = Field(gt=0, le=300, max_digits=4, decimal_places=1)
    roast_level: RoastLevel
    notes: str | None = None

    @model_validator(mode="after")
    def _out_le_in(self):
        if self.roasted_out_kg > self.green_in_kg:
            raise ValueError("roasted_out_kg no puede superar green_in_kg")
        return self


class RoastPatch(BaseModel):
    # default=None sin "| None": omitir = ignorar, null = 422. El lote no se puede cambiar.
    roasted_at: datetime = None
    green_in_kg: Decimal = Field(default=None, **Kg)
    roasted_out_kg: Decimal = Field(default=None, **Kg)
    duration_s: int = Field(default=None, gt=0, le=7200)
    drop_temp_c: Decimal = Field(default=None, gt=0, le=300, max_digits=4, decimal_places=1)
    roast_level: RoastLevel = None
    notes: str | None = None


def loss_pct(green_in: Decimal, out: Decimal) -> Decimal:
    return ((green_in - out) / green_in * 100).quantize(Decimal("0.01"))


def _roast_or_404(db: Session, roast_id: uuid.UUID) -> Roast:
    roast = db.get(Roast, roast_id)
    if not roast:
        raise ApiError(404, "not_found", "Tueste no encontrado")
    return roast


def _check_stock(db: Session, lot: GreenLot, needed: Decimal, exclude: uuid.UUID | None = None) -> None:
    available = lot.received_kg - used_kg(db, lot.id, exclude)
    if needed > available:
        raise ApiError(409, "insufficient_stock", f"Stock disponible: {available} kg")


@router.get("", response_model=Page[RoastOut])
def list_roasts(
    lot_id: uuid.UUID | None = None,
    level: RoastLevel | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    utc = timezone.utc  # los filtros de fecha se interpretan en UTC
    where = []
    if lot_id:
        where.append(Roast.lot_id == lot_id)
    if level:
        where.append(Roast.roast_level == level)
    if date_from:
        where.append(Roast.roasted_at >= datetime.combine(date_from, time.min, utc))
    if date_to:
        where.append(Roast.roasted_at < datetime.combine(date_to + timedelta(days=1), time.min, utc))
    rows = db.scalars(
        select(Roast).where(*where).order_by(Roast.roasted_at.desc()).limit(limit).offset(offset)
    ).all()
    total = db.scalar(select(func.count()).select_from(Roast).where(*where))
    return Page[RoastOut](
        items=[RoastOut.model_validate(r) for r in rows], total=total, limit=limit, offset=offset
    )


@router.get("/{roast_id}", response_model=RoastDetail)
def get_roast(roast_id: uuid.UUID, db: Session = Depends(get_db)):
    roast = _roast_or_404(db, roast_id)
    roast.lot.stock_kg = roast.lot.received_kg - used_kg(db, roast.lot_id)
    return roast


@router.post("", response_model=RoastOut, status_code=201)
def create_roast(body: RoastIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    lot = db.get(GreenLot, body.lot_id, with_for_update=True)  # serializa tuestes del mismo lote
    if not lot:
        raise ApiError(404, "lot_not_found", "Lote no encontrado")
    _check_stock(db, lot, body.green_in_kg)
    roast = Roast(
        **body.model_dump(), roaster_id=user.id, loss_pct=loss_pct(body.green_in_kg, body.roasted_out_kg)
    )
    db.add(roast)
    db.commit()
    db.refresh(roast)
    return roast


@router.patch("/{roast_id}", response_model=RoastOut)
def patch_roast(
    roast_id: uuid.UUID, body: RoastPatch, user: User = Depends(current_user), db: Session = Depends(get_db)
):
    roast = _roast_or_404(db, roast_id)
    if user.role != "admin" and roast.roaster_id != user.id:
        raise ApiError(403, "forbidden", "Solo el autor o un admin puede editar este tueste")
    changes = body.model_dump(exclude_unset=True)
    new_in = changes.get("green_in_kg", roast.green_in_kg)
    new_out = changes.get("roasted_out_kg", roast.roasted_out_kg)
    if new_out > new_in:
        raise ApiError(422, "validation_error", "roasted_out_kg no puede superar green_in_kg")
    lot = db.get(GreenLot, roast.lot_id, with_for_update=True)
    _check_stock(db, lot, new_in, exclude=roast.id)
    for k, v in changes.items():
        setattr(roast, k, v)
    roast.loss_pct = loss_pct(new_in, new_out)
    db.commit()
    return roast


@router.delete("/{roast_id}", status_code=204, dependencies=[Depends(admin_only)])
def delete_roast(roast_id: uuid.UUID, db: Session = Depends(get_db)):
    db.delete(_roast_or_404(db, roast_id))
    db.commit()
```

Modificar `api/app/main.py`: `from app.routers import auth, green_lots, roasts, users` y añadir `app.include_router(roasts.router, prefix="/api/v1")`.

- [ ] **Step 4: Verificar que pasan**

Run: `cd api && pytest -v`
Expected: todos pasan.

- [ ] **Step 5: Commit**

```bash
cd /Users/federicopizarro/Desktop/3
git add api
git commit -m "feat(api): roasts with stock validation, loss calculation and permissions"
```

---

### Task 7: Contenedor de la API + compose (db y api)

**Files:**
- Create: `api/Containerfile`, `api/.containerignore`, `compose.yaml`, `.env.example`

**Interfaces:**
- Produces: servicios compose `db` y `api` (red interna, sin puertos al host). Task 12 añade `web`.

- [ ] **Step 1: Escribir los archivos**

`api/Containerfile`:
```dockerfile
FROM docker.io/library/python:3.13-slim AS build
WORKDIR /src
COPY pyproject.toml ./
COPY app ./app
RUN pip install --no-cache-dir --prefix=/install .

FROM docker.io/library/python:3.13-slim
RUN useradd --create-home --uid 1000 app
COPY --from=build /install /usr/local
WORKDIR /srv
COPY alembic.ini ./
COPY alembic ./alembic
USER app
EXPOSE 8000
CMD ["sh", "-c", "alembic upgrade head && exec uvicorn app.main:app --host 0.0.0.0 --port 8000"]
```

`api/.containerignore`:
```
.venv
__pycache__
tests
*.egg-info
.pytest_cache
```

`.env.example`:
```bash
# Usar solo caracteres seguros para URL (p. ej. `openssl rand -hex 24`).
POSTGRES_PASSWORD=change-me
JWT_SECRET=change-me-with-at-least-32-characters
```

`compose.yaml`:
```yaml
services:
  db:
    image: docker.io/library/postgres:17-alpine
    environment:
      POSTGRES_USER: brewtrack
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: brewtrack
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U brewtrack"]
      interval: 5s
      timeout: 3s
      retries: 10

  api:
    build:
      context: ./api
      dockerfile: Containerfile
    environment:
      DATABASE_URL: postgresql+psycopg://brewtrack:${POSTGRES_PASSWORD}@db:5432/brewtrack
      JWT_SECRET: ${JWT_SECRET}
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/api/v1/health')"]
      interval: 10s
      timeout: 3s
      retries: 10

volumes:
  pgdata:
```

- [ ] **Step 2: Construir y levantar**

```bash
cd /Users/federicopizarro/Desktop/3
cp .env.example .env
sed -i '' "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(openssl rand -hex 16)/; s/^JWT_SECRET=.*/JWT_SECRET=$(openssl rand -hex 32)/" .env
podman compose up --build -d db api
sleep 15 && podman compose ps
```
Expected: `db` y `api` en estado `running` / `healthy`.

- [ ] **Step 3: Verificar health y migraciones dentro del contenedor**

```bash
podman compose exec api python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/api/v1/health').read())"
podman compose exec db psql -U brewtrack -c '\dt'
```
Expected: `b'{"status":"ok"}'` y las tablas `users`, `green_lots`, `roasts`, `alembic_version`.

- [ ] **Step 4: Verificar la CLI**

```bash
podman compose exec api python -m app.cli create-admin --email admin@brewtrack.dev --name Admin
```
Introducir una contraseña de 8+ caracteres. Expected: `Admin creado`.

- [ ] **Step 5: Commit**

```bash
podman compose down
git add compose.yaml .env.example api/Containerfile api/.containerignore
git commit -m "feat: containerize api and add compose with postgres"
```

---

### Task 8: Esqueleto de Flutter (modelos, API, auth, router, login, shell)

**Files:**
- Create: `web/` (proyecto Flutter), `web/lib/models.dart`, `web/lib/util.dart`, `web/lib/api.dart`, `web/lib/providers.dart`, `web/lib/router.dart`, `web/lib/shell.dart`, `web/lib/login_screen.dart`, `web/lib/widgets.dart`
- Modify: `web/lib/main.dart`, `web/pubspec.yaml` (vía `flutter pub add`)
- Test: `web/test/util_test.dart`, `web/test/shell_test.dart`

**Interfaces:**
- Produces:
  - `models.dart`: `User(id, email, name, role, active, isAdmin)`, `Lot(id, code, originCountry, region?, farm?, producer?, variety, process, altitudeM?, harvestYear, receivedAt, receivedKg, notes?, stockKg)`, `Roast(id, lotId, lotCode, roasterId, roasterName, roastedAt, greenInKg, roastedOutKg, lossPct, durationS, dropTempC, roastLevel, notes?)`, `LotDetail(lot, roasts)`, `RoastDetail(roast, lot)`, `Paged<T>(items, total)`, `pageFrom`, typedefs `LotFilter = ({String country, String process})` y `RoastFilter = ({String lotId, String level, String from, String to})`; todos con `fromJson(Map<String, dynamic>)`.
  - `util.dart`: `double? lossPct(double? inKg, double? outKg)`, `bool canEditRoast(User, Roast)`, `String fmtKg(double)`, `String fmtDate(DateTime)`.
  - `api.dart`: `apiMessage(Object)`, `Api` con `login`, `logout`, `restore`, `me`, `lots`, `lot`, `roasts`, `roast`, `users`, `send(method, path, [data])`.
  - `providers.dart`: `prefsProvider`, `apiProvider`, `authProvider` (`AsyncNotifierProvider<AuthController, User?>`), `lotsProvider`, `lotProvider`, `roastsProvider`, `roastProvider`, `usersProvider`.
  - `widgets.dart`: `asyncBody`, `confirm`, `toast`, `ResponsiveTable<T>`.
  - `shell.dart`: `Shell({child})`. `router.dart`: `routerProvider`.

- [ ] **Step 1: Crear el proyecto y dependencias**

Requiere Flutter (`flutter --version`; si falta, `brew install --cask flutter`).

```bash
cd /Users/federicopizarro/Desktop/3
flutter create --platforms web --project-name brewtrack_web web
cd web
flutter pub add flutter_riverpod:^2.6.1 go_router dio shared_preferences
rm test/widget_test.dart
```
Expected: `Got dependencies!`.

- [ ] **Step 2: Escribir los tests que fallan**

`web/test/util_test.dart`:
```dart
import 'package:brewtrack_web/models.dart';
import 'package:brewtrack_web/util.dart';
import 'package:flutter_test/flutter_test.dart';

Roast _roast(String roasterId) => Roast.fromJson({
      'id': 'r1', 'lot_id': 'l1', 'lot_code': 'GL-1', 'roaster_id': roasterId, 'roaster_name': 'Ana',
      'roasted_at': '2026-02-01T10:00:00Z', 'green_in_kg': 10, 'roasted_out_kg': 8.5, 'loss_pct': 15.0,
      'duration_s': 600, 'drop_temp_c': 205.0, 'roast_level': 'medium', 'notes': null,
    });

User _user(String id, String role) =>
    User(id: id, email: '$id@x.com', name: id, role: role, active: true);

void main() {
  test('lossPct calcula la merma', () {
    expect(lossPct(10, 8.5), closeTo(15, 1e-9));
    expect(lossPct(10, 10), 0);
  });

  test('lossPct devuelve null con pesos vacíos, cero o incoherentes', () {
    expect(lossPct(null, 5), isNull);
    expect(lossPct(10, null), isNull);
    expect(lossPct(0, 0), isNull);
    expect(lossPct(10, 11), isNull);
  });

  test('canEditRoast: autor o admin', () {
    final r = _roast('ana');
    expect(canEditRoast(_user('ana', 'roaster'), r), isTrue);
    expect(canEditRoast(_user('bob', 'roaster'), r), isFalse);
    expect(canEditRoast(_user('bob', 'admin'), r), isTrue);
  });
}
```

`web/test/shell_test.dart`:
```dart
import 'package:brewtrack_web/models.dart';
import 'package:brewtrack_web/providers.dart';
import 'package:brewtrack_web/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class FakeAuth extends AuthController {
  FakeAuth(this.u);
  final User? u;
  @override
  Future<User?> build() async => u;
}

Future<void> pumpShell(WidgetTester t, User u) async {
  final router = GoRouter(initialLocation: '/lots', routes: [
    ShellRoute(
      builder: (_, __, child) => Shell(child: child),
      routes: [
        GoRoute(path: '/lots', builder: (_, __) => const Text('lots-page')),
        GoRoute(path: '/roasts', builder: (_, __) => const Text('roasts-page')),
        GoRoute(path: '/users', builder: (_, __) => const Text('users-page')),
      ],
    ),
  ]);
  await t.pumpWidget(ProviderScope(
    overrides: [authProvider.overrideWith(() => FakeAuth(u))],
    child: MaterialApp.router(routerConfig: router),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('roaster no ve Usuarios', (t) async {
    await pumpShell(t, const User(id: '1', email: 'r@x.com', name: 'Rita', role: 'roaster', active: true));
    expect(find.text('Lotes'), findsOneWidget);
    expect(find.text('Tuestes'), findsOneWidget);
    expect(find.text('Usuarios'), findsNothing);
  });

  testWidgets('admin ve Usuarios', (t) async {
    await pumpShell(t, const User(id: '2', email: 'a@x.com', name: 'Ada', role: 'admin', active: true));
    expect(find.text('Usuarios'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Verificar que fallan**

Run: `cd web && flutter test`
Expected: FAIL (`Target of URI doesn't exist: 'package:brewtrack_web/models.dart'`).

- [ ] **Step 4: Implementar modelos y utilidades**

`web/lib/models.dart`:
```dart
double _d(Object? v) => (v as num).toDouble();

typedef LotFilter = ({String country, String process});
typedef RoastFilter = ({String lotId, String level, String from, String to});

class User {
  const User({required this.id, required this.email, required this.name, required this.role, required this.active});
  User.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        email = j['email'],
        name = j['name'],
        role = j['role'],
        active = j['active'];
  final String id, email, name, role;
  final bool active;
  bool get isAdmin => role == 'admin';
}

class Lot {
  Lot.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        code = j['code'],
        originCountry = j['origin_country'],
        region = j['region'],
        farm = j['farm'],
        producer = j['producer'],
        variety = j['variety'],
        process = j['process'],
        altitudeM = j['altitude_m'],
        harvestYear = j['harvest_year'],
        receivedAt = j['received_at'],
        receivedKg = _d(j['received_kg']),
        notes = j['notes'],
        stockKg = _d(j['stock_kg']);
  final String id, code, originCountry, variety, process, receivedAt;
  final String? region, farm, producer, notes;
  final int? altitudeM;
  final int harvestYear;
  final double receivedKg, stockKg;
}

class Roast {
  Roast.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        lotId = j['lot_id'],
        lotCode = j['lot_code'],
        roasterId = j['roaster_id'],
        roasterName = j['roaster_name'],
        roastedAt = DateTime.parse(j['roasted_at']),
        greenInKg = _d(j['green_in_kg']),
        roastedOutKg = _d(j['roasted_out_kg']),
        lossPct = _d(j['loss_pct']),
        durationS = j['duration_s'],
        dropTempC = _d(j['drop_temp_c']),
        roastLevel = j['roast_level'],
        notes = j['notes'];
  final String id, lotId, lotCode, roasterId, roasterName, roastLevel;
  final DateTime roastedAt;
  final double greenInKg, roastedOutKg, lossPct, dropTempC;
  final int durationS;
  final String? notes;
}

class LotDetail {
  LotDetail.fromJson(Map<String, dynamic> j)
      : lot = Lot.fromJson(j),
        roasts = [for (final r in j['roasts']) Roast.fromJson(r as Map<String, dynamic>)];
  final Lot lot;
  final List<Roast> roasts;
}

class RoastDetail {
  RoastDetail.fromJson(Map<String, dynamic> j)
      : roast = Roast.fromJson(j),
        lot = Lot.fromJson(j['lot'] as Map<String, dynamic>);
  final Roast roast;
  final Lot lot;
}

class Paged<T> {
  const Paged(this.items, this.total);
  final List<T> items;
  final int total;
}

Paged<T> pageFrom<T>(Map<String, dynamic> j, T Function(Map<String, dynamic>) f) =>
    Paged([for (final i in j['items']) f(i as Map<String, dynamic>)], j['total']);

const roastLevels = {'light': 'Claro', 'medium': 'Medio', 'dark': 'Oscuro'};
```

`web/lib/util.dart`:
```dart
import 'models.dart';

/// Merma en %, o null si los pesos están vacíos o son incoherentes.
double? lossPct(double? inKg, double? outKg) {
  if (inKg == null || outKg == null || inKg <= 0 || outKg < 0 || outKg > inKg) return null;
  return (inKg - outKg) / inKg * 100;
}

bool canEditRoast(User u, Roast r) => u.isAdmin || r.roasterId == u.id;

String fmtKg(double v) => '${v.toStringAsFixed(3)} kg';

/// 'AAAA-MM-DD HH:mm' en hora local.
String fmtDate(DateTime d) => d.toLocal().toIso8601String().substring(0, 16).replaceFirst('T', ' ');
```

- [ ] **Step 5: Implementar API y providers**

`web/lib/api.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// En desarrollo: `--dart-define=API_BASE=http://localhost:8000/api/v1`.
const apiBase = String.fromEnvironment('API_BASE', defaultValue: '/api/v1');
const _refreshKey = 'refresh_token';

String apiMessage(Object e) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['error'] is Map) return d['error']['message'] as String;
    return e.message ?? 'Error de red';
  }
  return e.toString();
}

class Api {
  Api(this._prefs, {Dio? dio}) : _dio = dio ?? Dio(BaseOptions(baseUrl: apiBase)) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) {
        if (_access != null) o.headers['Authorization'] = 'Bearer $_access';
        h.next(o);
      },
      onError: (e, h) async {
        final o = e.requestOptions;
        if (e.response?.statusCode != 401 || o.path.startsWith('/auth/') || !await restore()) {
          return h.next(e);
        }
        o.headers['Authorization'] = 'Bearer $_access';
        try {
          h.resolve(await _dio.fetch<dynamic>(o));
        } on DioException catch (e2) {
          h.next(e2);
        }
      },
    ));
  }

  final SharedPreferences _prefs;
  final Dio _dio;
  String? _access;

  /// Canjea el refresh token guardado por un access token nuevo.
  Future<bool> restore() async {
    final rt = _prefs.getString(_refreshKey);
    if (rt == null) return false;
    try {
      final r = await Dio(BaseOptions(baseUrl: _dio.options.baseUrl))
          .post<Map<String, dynamic>>('/auth/refresh', data: {'refresh_token': rt});
      _access = r.data!['access_token'];
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) await logout();
      return false;
    }
  }

  Future<void> login(String email, String password) async {
    final r = await _dio.post<Map<String, dynamic>>('/auth/login', data: {'email': email, 'password': password});
    _access = r.data!['access_token'];
    await _prefs.setString(_refreshKey, r.data!['refresh_token']);
  }

  Future<void> logout() async {
    _access = null;
    await _prefs.remove(_refreshKey);
  }

  Future<User> me() async => User.fromJson(await _get('/auth/me'));

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) async =>
      (await _dio.get<Map<String, dynamic>>(path, queryParameters: query)).data!;

  // ponytail: lista fija de 200 filas, sin paginación en la UI; añadirla si un taller supera eso.
  Future<Paged<Lot>> lots({String country = '', String process = ''}) async => pageFrom(
      await _get('/green-lots', {
        'limit': 200,
        if (country.isNotEmpty) 'country': country,
        if (process.isNotEmpty) 'process': process,
      }),
      Lot.fromJson);

  Future<LotDetail> lot(String id) async => LotDetail.fromJson(await _get('/green-lots/$id'));

  Future<Paged<Roast>> roasts(RoastFilter f) async => pageFrom(
      await _get('/roasts', {
        'limit': 200,
        if (f.lotId.isNotEmpty) 'lot_id': f.lotId,
        if (f.level.isNotEmpty) 'level': f.level,
        if (f.from.isNotEmpty) 'date_from': f.from,
        if (f.to.isNotEmpty) 'date_to': f.to,
      }),
      Roast.fromJson);

  Future<RoastDetail> roast(String id) async => RoastDetail.fromJson(await _get('/roasts/$id'));

  Future<List<User>> users() async => [
        for (final u in (await _dio.get<List<dynamic>>('/users')).data!) User.fromJson(u as Map<String, dynamic>)
      ];

  Future<void> send(String method, String path, [Object? data]) async {
    await _dio.request<void>(path, data: data, options: Options(method: method));
  }
}
```

`web/lib/providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError('override en main'));
final apiProvider = Provider<Api>((ref) => Api(ref.watch(prefsProvider)));

class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final api = ref.read(apiProvider);
    if (!await api.restore()) return null;
    return api.me();
  }

  Future<void> login(String email, String password) async {
    final api = ref.read(apiProvider);
    state = await AsyncValue.guard(() async {
      await api.login(email, password);
      return api.me();
    });
  }

  Future<void> logout() async {
    await ref.read(apiProvider).logout();
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthController, User?>(AuthController.new);

final lotsProvider = FutureProvider.autoDispose.family<Paged<Lot>, LotFilter>(
    (ref, f) => ref.watch(apiProvider).lots(country: f.country, process: f.process));
final lotProvider =
    FutureProvider.autoDispose.family<LotDetail, String>((ref, id) => ref.watch(apiProvider).lot(id));
final roastsProvider = FutureProvider.autoDispose
    .family<Paged<Roast>, RoastFilter>((ref, f) => ref.watch(apiProvider).roasts(f));
final roastProvider =
    FutureProvider.autoDispose.family<RoastDetail, String>((ref, id) => ref.watch(apiProvider).roast(id));
final usersProvider = FutureProvider.autoDispose<List<User>>((ref) => ref.watch(apiProvider).users());
```

- [ ] **Step 6: Implementar widgets compartidos, shell, login, router y main**

`web/lib/widgets.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';

Widget asyncBody<T>(AsyncValue<T> v, Widget Function(T) build) => v.when(
      data: build,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(apiMessage(e)))),
    );

Future<bool> confirm(BuildContext context, String text) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(content: Text(text), actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
      ]),
    ) ??
    false;

void toast(BuildContext context, Object e) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiMessage(e))));

/// Tabla en pantallas anchas, tarjetas en estrechas. No hace scroll por sí misma.
class ResponsiveTable<T> extends StatelessWidget {
  const ResponsiveTable({
    super.key,
    required this.items,
    required this.columns,
    required this.cells,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final List<T> items;
  final List<String> columns;
  final List<String> Function(T) cells;
  final String Function(T) title, subtitle;
  final void Function(T) onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Sin resultados')));
    }
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 720) {
        return Column(children: [
          for (final i in items)
            Card(child: ListTile(title: Text(title(i)), subtitle: Text(subtitle(i)), onTap: () => onTap(i))),
        ]);
      }
      return SizedBox(
        width: double.infinity,
        child: DataTable(
          showCheckboxColumn: false,
          columns: [for (final c in columns) DataColumn(label: Text(c))],
          rows: [
            for (final i in items)
              DataRow(onSelectChanged: (_) => onTap(i), cells: [for (final s in cells(i)) DataCell(Text(s))]),
          ],
        ),
      );
    });
  }
}
```

`web/lib/shell.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';

class Shell extends ConsumerWidget {
  const Shell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();
    final dests = [
      ('/lots', Icons.inventory_2, 'Lotes'),
      ('/roasts', Icons.local_fire_department, 'Tuestes'),
      if (user.isAdmin) ('/users', Icons.people, 'Usuarios'),
    ];
    final here = GoRouterState.of(context).matchedLocation;
    final idx = dests.indexWhere((d) => here.startsWith(d.$1)).clamp(0, dests.length - 1);
    return Scaffold(
      appBar: AppBar(
        title: const Text('BrewTrack'),
        actions: [
          Center(child: Text(user.name)),
          IconButton(
            tooltip: 'Salir',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(dests[i].$1),
        destinations: [for (final d in dests) NavigationDestination(icon: Icon(d.$2), label: d.$3)],
      ),
    );
  }
}
```

`web/lib/login_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    await ref.read(authProvider.notifier).login(_email.text.trim(), _password.text);
    final s = ref.read(authProvider);
    if (mounted) setState(() {
      _busy = false;
      _error = s.hasError ? apiMessage(s.error!) : null;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('BrewTrack', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _busy ? null : _submit, child: const Text('Entrar')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
```

`web/lib/router.dart` (las rutas de pantallas reales se reemplazan en las Tasks 9-11):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'login_screen.dart';
import 'providers.dart';
import 'shell.dart';

Widget _todo(String t) => Center(child: Text(t));

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);
  // ponytail: al recargar la página se pierde el deep link y se vuelve a /lots.
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final here = state.matchedLocation;
      if (auth.isLoading) return here == '/splash' ? null : '/splash';
      final user = auth.valueOrNull;
      if (user == null) return here == '/login' ? null : '/login';
      if (here == '/login' || here == '/splash' || (here.startsWith('/users') && !user.isAdmin)) {
        return '/lots';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (_, __, child) => Shell(child: child),
        routes: [
          GoRoute(
            path: '/lots',
            builder: (_, __) => _todo('Lotes'),
            routes: [GoRoute(path: ':id', builder: (_, s) => _todo('Lote ${s.pathParameters['id']}'))],
          ),
          GoRoute(
            path: '/roasts',
            builder: (_, __) => _todo('Tuestes'),
            routes: [GoRoute(path: ':id', builder: (_, s) => _todo('Tueste ${s.pathParameters['id']}'))],
          ),
          GoRoute(path: '/users', builder: (_, __) => _todo('Usuarios')),
        ],
      ),
    ],
  );
});
```

`web/lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const BrewTrackApp(),
  ));
}

class BrewTrackApp extends ConsumerWidget {
  const BrewTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'BrewTrack',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF6F4E37), useMaterial3: true),
        routerConfig: ref.watch(routerProvider),
      );
}
```

- [ ] **Step 7: Verificar**

Run: `cd web && flutter analyze && flutter test`
Expected: `No issues found!` y `All tests passed!` (5 tests). Corregir cualquier aviso del analizador antes de seguir.

- [ ] **Step 8: Commit**

```bash
cd /Users/federicopizarro/Desktop/3
git add web
git commit -m "feat(web): flutter skeleton with auth, router, shell and shared widgets"
```

---

### Task 9: Diálogo de edición genérico + pantallas de lotes

**Files:**
- Create: `web/lib/edit_dialog.dart`, `web/lib/lot_form.dart`, `web/lib/lots_screen.dart`, `web/lib/lot_detail_screen.dart`
- Modify: `web/lib/router.dart`

**Interfaces:**
- Consumes: `Api.send`, `asyncBody`, `confirm`, `toast`, `ResponsiveTable`, providers de Task 8.
- Produces: `showEditDialog(context, {title, fields, onSubmit, initial, footer}) -> Future<bool>` (true si guardó), `FieldSpec(key, label, {kind, required, options})`, `Kind {text, multiline, integer, decimal, date, datetime, select, password}`; `editLot(context, ref, [Lot?])`; `LotsScreen`, `LotDetailScreen(id)`. El diálogo muestra el mensaje del backend (409/422) dentro del propio diálogo.

- [ ] **Step 1: Escribir `web/lib/edit_dialog.dart`**

```dart
import 'package:flutter/material.dart';

import 'api.dart';

enum Kind { text, multiline, integer, decimal, date, datetime, select, password }

class FieldSpec {
  const FieldSpec(this.key, this.label, {this.kind = Kind.text, this.required = true, this.options = const {}});
  final String key, label;
  final Kind kind;
  final bool required;
  final Map<String, String> options; // valor -> etiqueta (solo select)
}

/// Muestra un formulario modal. `onSubmit` hace la llamada a la API; si lanza,
/// el mensaje del backend se muestra en el diálogo. Devuelve true si se guardó.
Future<bool> showEditDialog(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  required Future<void> Function(Map<String, dynamic> values) onSubmit,
  Map<String, dynamic> initial = const {},
  Widget Function(Map<String, dynamic> values)? footer,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _EditDialog(title: title, fields: fields, initial: initial, onSubmit: onSubmit, footer: footer),
    ) ??
    false;

class _EditDialog extends StatefulWidget {
  const _EditDialog({
    required this.title,
    required this.fields,
    required this.initial,
    required this.onSubmit,
    required this.footer,
  });
  final String title;
  final List<FieldSpec> fields;
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final Widget Function(Map<String, dynamic>)? footer;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c = {
    for (final f in widget.fields) f.key: TextEditingController(text: '${widget.initial[f.key] ?? ''}'),
  };
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  dynamic _parse(FieldSpec f) {
    final t = _c[f.key]!.text.trim();
    if (t.isEmpty) return null;
    switch (f.kind) {
      case Kind.integer:
        return int.tryParse(t);
      case Kind.decimal:
        return double.tryParse(t.replaceAll(',', '.'));
      case Kind.datetime:
        return DateTime.tryParse(t)?.toUtc().toIso8601String();
      default:
        return t;
    }
  }

  Map<String, dynamic> get _values => {for (final f in widget.fields) f.key: _parse(f)};

  Future<void> _pick(FieldSpec f) async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context, initialDate: now, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d == null || !mounted) return;
    var text = d.toIso8601String().substring(0, 10);
    if (f.kind == Kind.datetime) {
      final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
      if (t == null) return;
      text += ' ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    setState(() => _c[f.key]!.text = text);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_values);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = apiMessage(e);
          _busy = false;
        });
      }
    }
  }

  Widget _input(FieldSpec f) {
    final c = _c[f.key]!;
    String? validate(String? s) {
      if ((s ?? '').trim().isEmpty) return f.required ? 'Requerido' : null;
      return _parse(f) == null ? 'Valor inválido' : null;
    }

    final deco = InputDecoration(labelText: f.label, border: const OutlineInputBorder());
    switch (f.kind) {
      case Kind.select:
        return DropdownButtonFormField<String>(
          initialValue: f.options.containsKey(c.text) ? c.text : null,
          decoration: deco,
          isExpanded: true,
          items: [for (final e in f.options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          validator: validate,
          onChanged: (v) => setState(() => c.text = v ?? ''),
        );
      case Kind.date:
      case Kind.datetime:
        return TextFormField(
          controller: c,
          decoration: deco.copyWith(suffixIcon: const Icon(Icons.calendar_today)),
          readOnly: true,
          validator: validate,
          onTap: () => _pick(f),
        );
      default:
        return TextFormField(
          controller: c,
          decoration: deco,
          obscureText: f.kind == Kind.password,
          maxLines: f.kind == Kind.multiline ? 3 : 1,
          validator: validate,
          onChanged: (_) => setState(() {}),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final f in widget.fields) Padding(padding: const EdgeInsets.only(top: 12), child: _input(f)),
              if (widget.footer != null)
                Padding(padding: const EdgeInsets.only(top: 12), child: widget.footer!(_values)),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: _busy ? null : _submit, child: const Text('Guardar')),
      ],
    );
  }
}
```

- [ ] **Step 2: Escribir `web/lib/lot_form.dart`**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'edit_dialog.dart';
import 'models.dart';
import 'providers.dart';

const _lotFields = [
  FieldSpec('code', 'Código (ej. GL-2026-001)'),
  FieldSpec('origin_country', 'País de origen'),
  FieldSpec('region', 'Región', required: false),
  FieldSpec('farm', 'Finca', required: false),
  FieldSpec('producer', 'Productor', required: false),
  FieldSpec('variety', 'Variedad'),
  FieldSpec('process', 'Proceso (lavado, natural, honey…)'),
  FieldSpec('altitude_m', 'Altitud (msnm)', kind: Kind.integer, required: false),
  FieldSpec('harvest_year', 'Año de cosecha', kind: Kind.integer),
  FieldSpec('received_at', 'Fecha de recepción', kind: Kind.date),
  FieldSpec('received_kg', 'Kg recibidos', kind: Kind.decimal),
  FieldSpec('notes', 'Notas', kind: Kind.multiline, required: false),
];

Map<String, dynamic> _lotInitial(Lot l) => {
      'code': l.code,
      'origin_country': l.originCountry,
      'region': l.region,
      'farm': l.farm,
      'producer': l.producer,
      'variety': l.variety,
      'process': l.process,
      'altitude_m': l.altitudeM,
      'harvest_year': l.harvestYear,
      'received_at': l.receivedAt,
      'received_kg': l.receivedKg,
      'notes': l.notes,
    };

/// Alta (lot == null) o edición de un lote.
Future<void> editLot(BuildContext context, WidgetRef ref, [Lot? lot]) async {
  final api = ref.read(apiProvider);
  final saved = await showEditDialog(
    context,
    title: lot == null ? 'Nuevo lote' : 'Editar ${lot.code}',
    fields: _lotFields,
    initial: lot == null ? const {} : _lotInitial(lot),
    onSubmit: (v) => lot == null ? api.send('POST', '/green-lots', v) : api.send('PATCH', '/green-lots/${lot.id}', v),
  );
  if (saved) {
    ref.invalidate(lotsProvider);
    ref.invalidate(lotProvider);
  }
}
```

- [ ] **Step 3: Escribir `web/lib/lots_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'lot_form.dart';
import 'models.dart';
import 'providers.dart';
import 'util.dart';
import 'widgets.dart';

class LotsScreen extends ConsumerStatefulWidget {
  const LotsScreen({super.key});
  @override
  ConsumerState<LotsScreen> createState() => _LotsScreenState();
}

class _LotsScreenState extends ConsumerState<LotsScreen> {
  final _country = TextEditingController();
  final _process = TextEditingController();
  LotFilter _filter = (country: '', process: '');

  void _apply() => setState(() => _filter = (country: _country.text.trim(), process: _process.text.trim()));

  @override
  void dispose() {
    _country.dispose();
    _process.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 200,
            child: TextField(
              controller: _country,
              decoration: const InputDecoration(labelText: 'País', border: OutlineInputBorder()),
              onSubmitted: (_) => _apply(),
            ),
          ),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _process,
              decoration: const InputDecoration(labelText: 'Proceso', border: OutlineInputBorder()),
              onSubmitted: (_) => _apply(),
            ),
          ),
          OutlinedButton(onPressed: _apply, child: const Text('Filtrar')),
          FilledButton.icon(
            onPressed: () => editLot(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo lote'),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: asyncBody(
            ref.watch(lotsProvider(_filter)),
            (page) => SingleChildScrollView(
              child: ResponsiveTable<Lot>(
                items: page.items,
                columns: const ['Código', 'País', 'Variedad', 'Proceso', 'Recibido', 'Stock'],
                cells: (l) => [l.code, l.originCountry, l.variety, l.process, fmtKg(l.receivedKg), fmtKg(l.stockKg)],
                title: (l) => '${l.code} · ${l.originCountry}',
                subtitle: (l) => '${l.variety} · ${l.process} · stock ${fmtKg(l.stockKg)}',
                onTap: (l) => context.go('/lots/${l.id}'),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 4: Escribir `web/lib/lot_detail_screen.dart`**

`editRoast` se crea en la Task 10, así que aquí el archivo se escribe sin el botón "Registrar tueste" (la Task 10 lo añade) para que esta tarea compile:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'lot_form.dart';
import 'models.dart';
import 'providers.dart';
import 'util.dart';
import 'widgets.dart';

class LotDetailScreen extends ConsumerWidget {
  const LotDetailScreen(this.id, {super.key});
  final String id;

  Future<void> _delete(BuildContext context, WidgetRef ref, Lot l) async {
    if (!await confirm(context, '¿Eliminar el lote ${l.code}?')) return;
    try {
      await ref.read(apiProvider).send('DELETE', '/green-lots/${l.id}');
      ref.invalidate(lotsProvider);
      if (context.mounted) context.go('/lots');
    } catch (e) {
      if (context.mounted) toast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final text = Theme.of(context).textTheme;
    return asyncBody(ref.watch(lotProvider(id)), (d) {
      final l = d.lot;
      return ListView(padding: const EdgeInsets.all(16), children: [
        Text(l.code, style: text.headlineSmall),
        const SizedBox(height: 8),
        Text('${l.originCountry} · ${l.region ?? '—'} · ${l.farm ?? '—'} · ${l.producer ?? '—'}'),
        Text('${l.variety} · ${l.process} · cosecha ${l.harvestYear} · ${l.altitudeM ?? '—'} msnm'),
        Text('Recibido ${l.receivedAt}: ${fmtKg(l.receivedKg)} · Stock: ${fmtKg(l.stockKg)}'),
        if (l.notes != null) Text(l.notes!),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          OutlinedButton(onPressed: () => editLot(context, ref, l), child: const Text('Editar')),
          // Task 10 añade aquí el botón "Registrar tueste".
          if (user?.isAdmin ?? false)
            TextButton(onPressed: () => _delete(context, ref, l), child: const Text('Eliminar')),
        ]),
        const Divider(height: 32),
        Text('Tuestes', style: text.titleMedium),
        ResponsiveTable<Roast>(
          items: d.roasts,
          columns: const ['Fecha', 'Entrada', 'Salida', 'Merma', 'Nivel', 'Tostador'],
          cells: (r) => [
            fmtDate(r.roastedAt), fmtKg(r.greenInKg), fmtKg(r.roastedOutKg),
            '${r.lossPct.toStringAsFixed(1)} %', roastLevels[r.roastLevel] ?? r.roastLevel, r.roasterName,
          ],
          title: (r) => fmtDate(r.roastedAt),
          subtitle: (r) => '${fmtKg(r.greenInKg)} → ${fmtKg(r.roastedOutKg)} · ${r.lossPct.toStringAsFixed(1)} %',
          onTap: (r) => context.go('/roasts/${r.id}'),
        ),
      ]);
    });
  }
}
```

- [ ] **Step 5: Conectar las rutas**

En `web/lib/router.dart`, añadir imports `import 'lot_detail_screen.dart';` y `import 'lots_screen.dart';`, y reemplazar:
```dart
            builder: (_, __) => _todo('Lotes'),
            routes: [GoRoute(path: ':id', builder: (_, s) => _todo('Lote ${s.pathParameters['id']}'))],
```
por:
```dart
            builder: (_, __) => const LotsScreen(),
            routes: [GoRoute(path: ':id', builder: (_, s) => LotDetailScreen(s.pathParameters['id']!))],
```

- [ ] **Step 6: Verificar**

Run: `cd web && flutter analyze && flutter test`
Expected: `No issues found!` y tests en verde.

- [ ] **Step 7: Commit**

```bash
cd /Users/federicopizarro/Desktop/3
git add web
git commit -m "feat(web): generic edit dialog and green lot screens"
```

---

### Task 10: Pantallas de tuestes (formulario con merma en vivo)

**Files:**
- Create: `web/lib/roast_form.dart`, `web/lib/roasts_screen.dart`, `web/lib/roast_detail_screen.dart`
- Modify: `web/lib/lot_detail_screen.dart`, `web/lib/router.dart`
- Test: `web/test/roast_form_test.dart`

**Interfaces:**
- Consumes: `showEditDialog`, `FieldSpec`, `Kind`, `lossPct`, `canEditRoast`, providers.
- Produces: `roastFields(Map<String, String>? lotOptions) -> List<FieldSpec>` (incluye `lot_id` solo si `lotOptions != null`), `roastLossFooter(Map<String, dynamic>) -> Widget` (muestra `Merma: 15.0 %` o `Merma: —`), `editRoast(context, ref, {Roast? roast, String? lotId})`, `RoastsScreen`, `RoastDetailScreen(id)`.

- [ ] **Step 1: Escribir el test que falla**

`web/test/roast_form_test.dart`:
```dart
import 'package:brewtrack_web/edit_dialog.dart';
import 'package:brewtrack_web/roast_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el formulario de tueste muestra la merma en vivo', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showEditDialog(
              context,
              title: 'Tueste',
              fields: roastFields(const {'a': 'Lote A'}),
              footer: roastLossFooter,
              onSubmit: (_) async {},
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();

    final input = find.widgetWithText(TextFormField, 'Kg verde (entrada)');
    final output = find.widgetWithText(TextFormField, 'Kg tostado (salida)');

    expect(find.text('Merma: —'), findsOneWidget);
    await t.enterText(input, '10');
    await t.enterText(output, '8.5');
    await t.pump();
    expect(find.text('Merma: 15.0 %'), findsOneWidget);

    await t.enterText(input, '0'); // peso en cero: no debe romper ni dividir por cero
    await t.pump();
    expect(find.text('Merma: —'), findsOneWidget);

    await t.enterText(input, '5'); // salida mayor que entrada
    await t.pump();
    expect(find.text('Merma: —'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Verificar que falla**

Run: `cd web && flutter test test/roast_form_test.dart`
Expected: FAIL (`roast_form.dart` no existe).

- [ ] **Step 3: Implementar `web/lib/roast_form.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'edit_dialog.dart';
import 'models.dart';
import 'providers.dart';
import 'util.dart';

List<FieldSpec> roastFields(Map<String, String>? lotOptions) => [
      if (lotOptions != null) FieldSpec('lot_id', 'Lote', kind: Kind.select, options: lotOptions),
      const FieldSpec('roasted_at', 'Fecha y hora', kind: Kind.datetime),
      const FieldSpec('green_in_kg', 'Kg verde (entrada)', kind: Kind.decimal),
      const FieldSpec('roasted_out_kg', 'Kg tostado (salida)', kind: Kind.decimal),
      const FieldSpec('duration_s', 'Duración (segundos)', kind: Kind.integer),
      const FieldSpec('drop_temp_c', 'Temperatura de descarga (°C)', kind: Kind.decimal),
      const FieldSpec('roast_level', 'Nivel de tueste', kind: Kind.select, options: roastLevels),
      const FieldSpec('notes', 'Notas', kind: Kind.multiline, required: false),
    ];

Widget roastLossFooter(Map<String, dynamic> v) {
  final l = lossPct((v['green_in_kg'] as num?)?.toDouble(), (v['roasted_out_kg'] as num?)?.toDouble());
  return Align(
    alignment: Alignment.centerLeft,
    child: Text(l == null ? 'Merma: —' : 'Merma: ${l.toStringAsFixed(1)} %'),
  );
}

Map<String, dynamic> _roastInitial(Roast r) => {
      'roasted_at': fmtDate(r.roastedAt),
      'green_in_kg': r.greenInKg,
      'roasted_out_kg': r.roastedOutKg,
      'duration_s': r.durationS,
      'drop_temp_c': r.dropTempC,
      'roast_level': r.roastLevel,
      'notes': r.notes,
    };

/// Alta (roast == null, con `lotId` opcional preseleccionado) o edición de un tueste.
Future<void> editRoast(BuildContext context, WidgetRef ref, {Roast? roast, String? lotId}) async {
  final api = ref.read(apiProvider);
  Map<String, String>? lotOptions;
  if (roast == null) {
    final lots = (await api.lots()).items;
    lotOptions = {for (final l in lots) l.id: '${l.code} · stock ${l.stockKg.toStringAsFixed(1)} kg'};
  }
  if (!context.mounted) return;
  final saved = await showEditDialog(
    context,
    title: roast == null ? 'Nuevo tueste' : 'Editar tueste',
    fields: roastFields(lotOptions),
    initial: roast == null ? {'lot_id': lotId} : _roastInitial(roast),
    footer: roastLossFooter,
    onSubmit: (v) => roast == null ? api.send('POST', '/roasts', v) : api.send('PATCH', '/roasts/${roast.id}', v),
  );
  if (saved) {
    ref.invalidate(roastsProvider);
    ref.invalidate(roastProvider);
    ref.invalidate(lotProvider);
    ref.invalidate(lotsProvider);
  }
}
```

- [ ] **Step 4: Escribir `web/lib/roasts_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models.dart';
import 'providers.dart';
import 'roast_form.dart';
import 'util.dart';
import 'widgets.dart';

class RoastsScreen extends ConsumerStatefulWidget {
  const RoastsScreen({super.key});
  @override
  ConsumerState<RoastsScreen> createState() => _RoastsScreenState();
}

class _RoastsScreenState extends ConsumerState<RoastsScreen> {
  final _from = TextEditingController();
  final _to = TextEditingController();
  String _lotId = '';
  String _level = '';
  String _fromApplied = '';
  String _toApplied = '';

  void _apply() => setState(() {
        _fromApplied = _from.text.trim();
        _toApplied = _to.text.trim();
      });

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lots = ref.watch(lotsProvider((country: '', process: ''))).valueOrNull?.items ?? const <Lot>[];
    final filter = (lotId: _lotId, level: _level, from: _fromApplied, to: _toApplied);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DropdownButton<String>(
            value: _lotId,
            items: [
              const DropdownMenuItem(value: '', child: Text('Todos los lotes')),
              for (final l in lots) DropdownMenuItem(value: l.id, child: Text(l.code)),
            ],
            onChanged: (v) => setState(() => _lotId = v ?? ''),
          ),
          DropdownButton<String>(
            value: _level,
            items: [
              const DropdownMenuItem(value: '', child: Text('Todos los niveles')),
              for (final e in roastLevels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _level = v ?? ''),
          ),
          // ponytail: fechas como texto AAAA-MM-DD; la API responde 422 si el formato es inválido.
          SizedBox(
            width: 170,
            child: TextField(
              controller: _from,
              decoration: const InputDecoration(labelText: 'Desde (AAAA-MM-DD)', border: OutlineInputBorder()),
              onSubmitted: (_) => _apply(),
            ),
          ),
          SizedBox(
            width: 170,
            child: TextField(
              controller: _to,
              decoration: const InputDecoration(labelText: 'Hasta (AAAA-MM-DD)', border: OutlineInputBorder()),
              onSubmitted: (_) => _apply(),
            ),
          ),
          OutlinedButton(onPressed: _apply, child: const Text('Filtrar')),
          FilledButton.icon(
            onPressed: () => editRoast(context, ref, lotId: _lotId.isEmpty ? null : _lotId),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo tueste'),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: asyncBody(
            ref.watch(roastsProvider(filter)),
            (page) => SingleChildScrollView(
              child: ResponsiveTable<Roast>(
                items: page.items,
                columns: const ['Fecha', 'Lote', 'Entrada', 'Salida', 'Merma', 'Nivel', 'Tostador'],
                cells: (r) => [
                  fmtDate(r.roastedAt), r.lotCode, fmtKg(r.greenInKg), fmtKg(r.roastedOutKg),
                  '${r.lossPct.toStringAsFixed(1)} %', roastLevels[r.roastLevel] ?? r.roastLevel, r.roasterName,
                ],
                title: (r) => '${r.lotCode} · ${fmtDate(r.roastedAt)}',
                subtitle: (r) =>
                    '${fmtKg(r.greenInKg)} → ${fmtKg(r.roastedOutKg)} · ${r.lossPct.toStringAsFixed(1)} % · ${r.roasterName}',
                onTap: (r) => context.go('/roasts/${r.id}'),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 5: Escribir `web/lib/roast_detail_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';
import 'roast_form.dart';
import 'util.dart';
import 'widgets.dart';

class RoastDetailScreen extends ConsumerWidget {
  const RoastDetailScreen(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final text = Theme.of(context).textTheme;
    return asyncBody(ref.watch(roastProvider(id)), (d) {
      final r = d.roast;
      final l = d.lot;
      return ListView(padding: const EdgeInsets.all(16), children: [
        Text('Tueste de ${r.lotCode}', style: text.headlineSmall),
        const SizedBox(height: 8),
        Text('${fmtDate(r.roastedAt)} · por ${r.roasterName}'),
        Text('Entrada ${fmtKg(r.greenInKg)} → salida ${fmtKg(r.roastedOutKg)} · merma ${r.lossPct.toStringAsFixed(1)} %'),
        Text('${r.durationS} s · descarga ${r.dropTempC.toStringAsFixed(1)} °C · ${roastLevels[r.roastLevel]}'),
        if (r.notes != null) Text(r.notes!),
        const Divider(height: 32),
        Text('Lote de origen', style: text.titleMedium),
        Text('${l.code} · ${l.originCountry} · ${l.region ?? '—'} · ${l.farm ?? '—'}'),
        Text('${l.variety} · ${l.process} · stock ${fmtKg(l.stockKg)}'),
        TextButton(onPressed: () => context.go('/lots/${l.id}'), child: const Text('Ver lote')),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          if (user != null && canEditRoast(user, r))
            OutlinedButton(onPressed: () => editRoast(context, ref, roast: r), child: const Text('Editar')),
          if (user?.isAdmin ?? false)
            TextButton(
              onPressed: () async {
                if (!await confirm(context, '¿Eliminar este tueste?')) return;
                try {
                  await ref.read(apiProvider).send('DELETE', '/roasts/${r.id}');
                  ref.invalidate(roastsProvider);
                  ref.invalidate(lotProvider);
                  ref.invalidate(lotsProvider);
                  if (context.mounted) context.go('/roasts');
                } catch (e) {
                  if (context.mounted) toast(context, e);
                }
              },
              child: const Text('Eliminar'),
            ),
        ]),
      ]);
    });
  }
}
```

- [ ] **Step 6: Botón "Registrar tueste" en el detalle de lote y rutas**

En `web/lib/lot_detail_screen.dart`: añadir `import 'roast_form.dart';` y reemplazar la línea
```dart
          // Task 10 añade aquí el botón "Registrar tueste".
```
por
```dart
          FilledButton(
            onPressed: () => editRoast(context, ref, lotId: l.id),
            child: const Text('Registrar tueste'),
          ),
```

En `web/lib/router.dart`: añadir `import 'roast_detail_screen.dart';` y `import 'roasts_screen.dart';`, y reemplazar
```dart
            builder: (_, __) => _todo('Tuestes'),
            routes: [GoRoute(path: ':id', builder: (_, s) => _todo('Tueste ${s.pathParameters['id']}'))],
```
por
```dart
            builder: (_, __) => const RoastsScreen(),
            routes: [GoRoute(path: ':id', builder: (_, s) => RoastDetailScreen(s.pathParameters['id']!))],
```

- [ ] **Step 7: Verificar**

Run: `cd web && flutter analyze && flutter test`
Expected: `No issues found!` y todos los tests en verde (incluye el de merma en vivo).

- [ ] **Step 8: Commit**

```bash
cd /Users/federicopizarro/Desktop/3
git add web
git commit -m "feat(web): roast screens with live loss calculation"
```

---

### Task 11: Pantalla de usuarios (solo admin)

**Files:**
- Create: `web/lib/users_screen.dart`
- Modify: `web/lib/router.dart`

**Interfaces:**
- Consumes: `showEditDialog`, `FieldSpec`, `usersProvider`, `Api.send`.
- Produces: `UsersScreen`. Crear usuario, editar nombre/rol/contraseña (opcional) y activar/desactivar con un switch; el 409 `last_admin` se muestra en un SnackBar.

- [ ] **Step 1: Escribir `web/lib/users_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'edit_dialog.dart';
import 'models.dart';
import 'providers.dart';
import 'widgets.dart';

const _roles = {'roaster': 'Tostador', 'admin': 'Admin'};

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final api = ref.read(apiProvider);
    final saved = await showEditDialog(
      context,
      title: 'Nuevo usuario',
      fields: const [
        FieldSpec('email', 'Email'),
        FieldSpec('name', 'Nombre'),
        FieldSpec('password', 'Contraseña (mín. 8)', kind: Kind.password),
        FieldSpec('role', 'Rol', kind: Kind.select, options: _roles),
      ],
      initial: const {'role': 'roaster'},
      onSubmit: (v) => api.send('POST', '/users', v),
    );
    if (saved) ref.invalidate(usersProvider);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, User u) async {
    final api = ref.read(apiProvider);
    final saved = await showEditDialog(
      context,
      title: 'Editar ${u.email}',
      fields: const [
        FieldSpec('name', 'Nombre'),
        FieldSpec('role', 'Rol', kind: Kind.select, options: _roles),
        FieldSpec('password', 'Nueva contraseña (opcional)', kind: Kind.password, required: false),
      ],
      initial: {'name': u.name, 'role': u.role},
      onSubmit: (v) {
        v.removeWhere((_, x) => x == null); // contraseña vacía = no cambiarla
        return api.send('PATCH', '/users/${u.id}', v);
      },
    );
    if (saved) ref.invalidate(usersProvider);
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, User u, bool active) async {
    try {
      await ref.read(apiProvider).send('PATCH', '/users/${u.id}', {'active': active});
      ref.invalidate(usersProvider);
    } catch (e) {
      if (context.mounted) toast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncBody(
      ref.watch(usersProvider),
      (users) => ListView(padding: const EdgeInsets.all(16), children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _create(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo usuario'),
          ),
        ),
        const SizedBox(height: 8),
        for (final u in users)
          Card(
            child: ListTile(
              title: Text(u.name),
              subtitle: Text('${u.email} · ${_roles[u.role]}'),
              onTap: () => _edit(context, ref, u),
              trailing: Switch(value: u.active, onChanged: (v) => _toggle(context, ref, u, v)),
            ),
          ),
      ]),
    );
  }
}
```

- [ ] **Step 2: Conectar la ruta**

En `web/lib/router.dart`: añadir `import 'users_screen.dart';`, reemplazar `GoRoute(path: '/users', builder: (_, __) => _todo('Usuarios')),` por `GoRoute(path: '/users', builder: (_, __) => const UsersScreen()),` y eliminar la función `_todo` y el import de `package:flutter/material.dart` solo si el analizador reporta que ya no se usa (el `ValueNotifier` lo sigue necesitando, así que normalmente se mantiene).

- [ ] **Step 3: Verificar**

Run: `cd web && flutter analyze && flutter test`
Expected: `No issues found!` y tests en verde. Si queda `_todo` sin usar, borrarlo.

- [ ] **Step 4: Commit**

```bash
cd /Users/federicopizarro/Desktop/3
git add web
git commit -m "feat(web): admin users screen"
```

---

### Task 12: Contenedor web, compose completo, README y prueba de humo

**Files:**
- Create: `web/Containerfile`, `web/nginx.conf`, `web/.containerignore`, `README.md`
- Modify: `compose.yaml`

**Interfaces:**
- Produces: servicio `web` (nginx, puerto host 8080) con proxy `/api/` → `api:8000`.

- [ ] **Step 1: Escribir los archivos**

`web/nginx.conf`:
```nginx
server {
  listen 80;
  root /usr/share/nginx/html;
  index index.html;

  location /api/ {
    proxy_pass http://api:8000;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }

  location / {
    try_files $uri $uri/ /index.html;
  }
}
```

`web/Containerfile`:
```dockerfile
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

FROM docker.io/library/nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
```

`web/.containerignore`:
```
build
.dart_tool
.idea
```

Añadir a `compose.yaml`, dentro de `services:` tras `api`:
```yaml
  web:
    build:
      context: ./web
      dockerfile: Containerfile
    ports:
      - "8080:80"
    depends_on:
      api:
        condition: service_healthy
```

`README.md`:
````markdown
# BrewTrack

Trazabilidad de café de especialidad: lotes de café verde y tuestes. API FastAPI + frontend Flutter Web + PostgreSQL, con Podman.

## Arrancar

```bash
cp .env.example .env   # y rellenar POSTGRES_PASSWORD y JWT_SECRET
podman compose up --build -d
podman compose exec api python -m app.cli create-admin --email tu@correo.dev --name "Tu Nombre"
```
Abrir http://localhost:8080.

## Desarrollo

```bash
podman compose up -d db                       # solo la base de datos
cd api && . .venv/bin/activate && pytest      # requiere el Postgres de pruebas (ver docs/superpowers/plans, Task 2)
cd api && uvicorn app.main:app --reload       # DATABASE_URL y JWT_SECRET en el entorno
cd web && flutter run -d chrome --web-port 5000 --dart-define=API_BASE=http://localhost:8000/api/v1
cd web && flutter test
```

## Backup

```bash
podman compose exec db pg_dump -U brewtrack brewtrack > backup-$(date +%F).sql
```
````

- [ ] **Step 2: Construir y levantar todo**

```bash
cd /Users/federicopizarro/Desktop/3
podman compose up --build -d
sleep 20 && podman compose ps
```
Expected: `db`, `api` y `web` en `running`; `api` `healthy`. (El primer build de Flutter tarda varios minutos.)

- [ ] **Step 3: Prueba de humo por HTTP (proxy de nginx)**

```bash
curl -s localhost:8080/api/v1/health
podman compose exec api python -m app.cli create-admin --email admin@brewtrack.dev --name Admin
TOKEN=$(curl -s localhost:8080/api/v1/auth/login -H 'content-type: application/json' \
  -d '{"email":"admin@brewtrack.dev","password":"<la contraseña elegida>"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')
curl -s localhost:8080/api/v1/green-lots -H "authorization: Bearer $TOKEN"
```
Expected: `{"status":"ok"}`, luego `Admin creado` (omitir si ya existe), y `{"items":[],"total":0,"limit":50,"offset":0}`.

- [ ] **Step 4: Prueba manual en el navegador**

Abrir http://localhost:8080 y comprobar, en este orden:
1. Login con el admin. Entra a **Lotes**.
2. Crear un lote de 60 kg. Aparece con stock 60 kg.
3. Desde su detalle, **Registrar tueste** con 10 kg de entrada y 8.5 de salida: el diálogo muestra `Merma: 15.0 %` en vivo. Guardar. El stock del lote baja a 50 kg.
4. Intentar un tueste de 100 kg: el diálogo muestra el mensaje 409 del backend y no se cierra.
5. Intentar eliminar el lote con tuestes (como admin): SnackBar con el mensaje del 409.
6. En **Usuarios**, crear un tostador; cerrar sesión y entrar con él: no ve la pestaña Usuarios ni el botón Eliminar.
7. Recargar la página: la sesión se mantiene (refresh token).

- [ ] **Step 5: Suites completas**

```bash
cd api && . .venv/bin/activate && pytest -q
cd ../web && flutter analyze && flutter test
```
Expected: todo en verde.

- [ ] **Step 6: Commit**

```bash
cd /Users/federicopizarro/Desktop/3
podman compose down
git add web compose.yaml README.md
git commit -m "feat: containerize web, complete compose stack and add README"
```

---

## Self-Review

**Cobertura de la spec:** modelo de datos y constraints (Task 2), auth/JWT/CLI (3), usuarios (4), lotes con stock, filtros y paginación (5), tuestes con validación de stock y permisos autor/admin (6), contenedores `db`/`api` (7), 5 pantallas Flutter, roles ocultos, errores del backend, responsive (8-11), `web` + nginx + proxy + backup + README (12), pruebas de API y de widgets (en cada tarea). Fuera de alcance respetado (sin curvas, sin multi-tenant, sin CI/TLS).

**Placeholders:** ninguno; cada paso de código trae el código completo.

**Consistencia de tipos:** `stock_kg` (API) ↔ `stockKg` (Dart); `lot_code`/`roaster_name` salen de propiedades de `Roast` y se consumen en `RoastOut`; `Page`/`Paged`; `FieldSpec`/`Kind`/`showEditDialog` definidos en Task 9 y reutilizados en 10 y 11; `roastLevels` definido en `models.dart` y usado en `roast_form.dart` y las pantallas.

**Decisiones de implementación que la spec dejaba abiertas:** `region`, `farm`, `producer`, `altitude_m` y `notes` de lote son opcionales; el lote de un tueste no se puede cambiar (borrar y recrear); los filtros de fecha de `/roasts` se interpretan en UTC; los filtros de texto de `/green-lots` son "contiene" sin distinguir mayúsculas; la UI no pagina (límite fijo de 200).
