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
