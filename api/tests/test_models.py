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
