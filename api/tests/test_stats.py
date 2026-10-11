from datetime import date, datetime
from zoneinfo import ZoneInfo

import pytest
from pydantic import ValidationError

from app.config import Settings, settings

URL = "/api/v1/stats/summary"
BA = ZoneInfo("America/Argentina/Buenos_Aires")
ZERO_RECEIVED = {"lots": 0, "kg": "0.000"}
ZERO_ROASTED = {"roasts": 0, "green_kg": "0.000", "roasted_kg": "0.000"}


@pytest.fixture(autouse=True)
def _ba(monkeypatch):
    monkeypatch.setattr(settings, "timezone", "America/Argentina/Buenos_Aires")


def _get(client, auth, user, month=None):
    r = client.get(URL, params={"month": month} if month else None, headers=auth(user))
    assert r.status_code == 200, r.text
    return r.json()


def test_requires_auth(client):
    r = client.get(URL)
    assert r.status_code == 401 and set(r.json()["error"]) == {"code", "message"}


@pytest.mark.parametrize("role", ["roaster", "admin"])
def test_both_roles(client, make_user, auth, role):
    body = _get(client, auth, make_user(f"{role}@x.com", role))
    assert set(body) == {"month", "lots_in_stock", "stock_kg", "received", "roasted", "loss_pct"}


@pytest.mark.parametrize("month", ["2026-13", "octubre", "2026-1", "2026-00", "0000-01", "9999-12"])
def test_bad_month_is_422(client, roaster, auth, month):
    r = client.get(URL, params={"month": month}, headers=auth(roaster))
    assert r.status_code == 422 and r.json()["error"]["code"] == "validation_error"


def test_received_counts_only_the_month(client, roaster, auth, make_lot):
    make_lot("GL-1", kg="50", received_at=date(2026, 9, 30))
    make_lot("GL-2", kg="60", received_at=date(2026, 10, 1))
    make_lot("GL-3", kg="60", received_at=date(2026, 10, 31))
    assert _get(client, auth, roaster, "2026-10")["received"] == {"lots": 2, "kg": "120.000"}


def test_roasted_counts_only_the_month(client, roaster, auth, make_lot, make_roast):
    lot = make_lot(kg="100")
    mid_oct = datetime(2026, 10, 15, 12, tzinfo=BA)
    make_roast(lot, roaster, "10", "8.5", roasted_at=mid_oct)
    make_roast(lot, roaster, "5", "4", roasted_at=mid_oct)
    make_roast(lot, roaster, "20", "17", roasted_at=datetime(2026, 9, 15, 12, tzinfo=BA))
    body = _get(client, auth, roaster, "2026-10")
    assert body["roasted"] == {"roasts": 2, "green_kg": "15.000", "roasted_kg": "12.500"}


def test_loss_is_weighted_not_averaged(client, roaster, auth, make_lot, make_roast):
    lot = make_lot(kg="100")
    at = datetime(2026, 10, 15, 12, tzinfo=BA)
    make_roast(lot, roaster, "1", "0.5", roasted_at=at)  # merma 50 %
    make_roast(lot, roaster, "19", "17.1", roasted_at=at)  # merma 10 %
    assert _get(client, auth, roaster, "2026-10")["loss_pct"] == "12.00"  # el promedio sería 30.00


def test_loss_rounds_half_up(client, roaster, auth, make_lot, make_roast):
    lot = make_lot(kg="100")
    make_roast(lot, roaster, "20", "17.531", roasted_at=datetime(2026, 10, 15, 12, tzinfo=BA))  # 12.345 %
    assert _get(client, auth, roaster, "2026-10")["loss_pct"] == "12.35"


def test_stock_today_matches_lot_listing(client, roaster, auth, make_lot, make_roast):
    used_up, partial = make_lot("GL-1", kg="30"), make_lot("GL-2", kg="20")
    make_lot("GL-3", kg="7.25")  # sin tuestes
    make_roast(used_up, roaster, "20", "17")
    make_roast(used_up, roaster, "10", "8.5")
    make_roast(partial, roaster, "5", "4")
    body = _get(client, auth, roaster, "2020-01")  # el stock no depende del mes
    assert body["lots_in_stock"] == 2 and body["stock_kg"] == "22.250"
    lots = client.get("/api/v1/green-lots", headers=auth(roaster)).json()["items"]
    assert float(body["stock_kg"]) == pytest.approx(sum(lot["stock_kg"] for lot in lots))


def test_future_dated_lot_counts_in_stock_today(client, roaster, auth, make_lot):
    make_lot(kg="10", received_at=date(2099, 1, 1))
    body = _get(client, auth, roaster)
    assert body["lots_in_stock"] == 1 and body["stock_kg"] == "10.000"


def test_month_edges_use_workshop_timezone(client, roaster, auth, make_lot, make_roast):
    lot = make_lot(kg="100")
    make_roast(lot, roaster, roasted_at=datetime(2026, 10, 31, 22, tzinfo=BA))  # 01-11 01:00 UTC
    make_roast(lot, roaster, roasted_at=datetime(2026, 10, 1, 0, tzinfo=BA))
    assert _get(client, auth, roaster, "2026-10")["roasted"]["roasts"] == 2
    assert _get(client, auth, roaster, "2026-11")["roasted"]["roasts"] == 0
    assert _get(client, auth, roaster, "2026-09")["roasted"]["roasts"] == 0


def test_year_rollover(client, roaster, auth, make_lot, make_roast):
    lot = make_lot(kg="100")
    make_roast(lot, roaster, roasted_at=datetime(2026, 12, 31, 23, tzinfo=BA))
    assert _get(client, auth, roaster, "2026-12")["roasted"]["roasts"] == 1
    assert _get(client, auth, roaster, "2027-01")["roasted"]["roasts"] == 0


@pytest.mark.parametrize("month", ["2020-01", "2099-01"])
def test_empty_month_returns_zeros(client, roaster, auth, month):
    body = _get(client, auth, roaster, month)
    assert body["month"] == month
    assert body["received"] == ZERO_RECEIVED and body["roasted"] == ZERO_ROASTED
    assert body["loss_pct"] is None and body["stock_kg"] == "0.000"


def test_default_month_is_current_in_workshop_timezone(client, roaster, auth):
    assert _get(client, auth, roaster)["month"] == datetime.now(BA).strftime("%Y-%m")


def test_timezone_default_and_validation(monkeypatch):
    monkeypatch.delenv("TIMEZONE", raising=False)
    assert Settings().timezone == "America/Argentina/Buenos_Aires"
    monkeypatch.setenv("TIMEZONE", "Marte/Olympus")
    with pytest.raises(ValidationError):
        Settings()
