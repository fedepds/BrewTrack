import os
from datetime import date, datetime, timezone
from decimal import Decimal
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
from app.models import GreenLot, Roast, User
from app.security import create_access_token, hash_password

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
