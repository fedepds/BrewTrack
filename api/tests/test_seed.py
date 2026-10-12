"""Pruebas de la spec 002: lotes y tuestes de ejemplo. Las tablas son copia literal de la spec."""
import logging
from datetime import date, datetime
from decimal import Decimal
from zoneinfo import ZoneInfo

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select

from app import cli, seed
from app.config import settings
from app.main import app
from app.models import GreenLot, Roast, User
from app.routers.green_lots import LotIn
from app.routers.roasts import RoastIn

LOTS_TABLE = """
GL-2025-001|Brasil|Sul de Minas|Fazenda Santa Inês|Família Pereira|Yellow Bourbon|Natural|1100|2025|2025-11-11|120.000
GL-2025-002|Brasil|Cerrado Mineiro|Fazenda Boa Vista|Família Costa|Mundo Novo|Despulpado natural|(vacío)|2025|2025-11-11|180.000
GL-2025-003|Colombia|Huila|La Esperanza|Familia Rojas|Caturra|Lavado|1750|2025|2025-12-02|70.000
GL-2025-004|Colombia|Nariño|El Mirador|Asociación de Productores de Buesaco|Castillo|Lavado|2100|2025|2025-12-02|140.000
GL-2026-001|Colombia|Cauca|Las Brisas|Hernán Muñoz|Pink Bourbon|Honey|1850|2025|2026-01-13|35.000
GL-2026-002|Bolivia|Caranavi|Finca Illimani|Familia Mamani|Java|Natural|1650|2025|2026-02-17|69.000
GL-2026-003|Perú|Cajamarca|El Huabo|Cooperativa de San Ignacio|Bourbon, Typica|Lavado|1800|2025|2026-02-17|69.000
GL-2026-004|Ruanda|Nyamasheke|Estación Muhondo|Cooperativa de Nyamasheke|Red Bourbon|Lavado|1800|2025|2026-03-10|60.000
GL-2026-005|Guatemala|Huehuetenango|Finca Los Altos|Familia Villatoro|Bourbon, Caturra|Lavado|1800|2026|2026-04-14|69.000
GL-2026-006|Guatemala|Antigua|Finca San Rafael|Familia Zelaya|Bourbon|Lavado|1600|2026|2026-04-14|138.000
GL-2026-007|Honduras|Marcala|El Cedro|Cooperativa de Marcala|Catuaí|Lavado|1500|2026|2026-04-28|69.000
GL-2026-008|El Salvador|Santa Ana|Finca Los Naranjos|Familia Aguilar|Pacamara|Honey|1650|2026|2026-04-28|34.500
GL-2026-009|Costa Rica|Tarrazú|Finca El Llano|Familia Solís|Caturra, Catuaí|Honey|1700|2026|2026-05-12|69.000
GL-2026-010|Costa Rica|Valle Occidental|Finca Alto Naranjo|Familia Vargas|Villa Sarchí|Natural|1500|2026|2026-05-12|34.500
GL-2026-011|Etiopía|Yirgacheffe|Estación Konga|Cooperativa Konga|Heirloom etíope|Lavado|2000|2026|2026-05-26|60.000
GL-2026-012|Etiopía|Guji|Estación Hambela|Productores de Hambela|Heirloom etíope|Natural|2150|2026|2026-05-26|120.000
GL-2026-013|Panamá|Boquete|Finca Las Nubes|Familia Serracín|Geisha|Lavado|1700|2026|2026-06-09|15.000
GL-2026-014|Panamá|Volcán|Finca Cerro Punta|Familia Araúz|Catuaí|Natural|1500|2026|2026-06-09|30.000
GL-2026-015|Kenia|Nyeri|Gaturiri|Cooperativa de Gaturiri|SL28, SL34|Lavado|1750|2025|2026-07-07|60.000
GL-2026-016|Indonesia|Aceh (Gayo)|Lago Tawar|Cooperativa Gayo|Ateng, Tim Tim|Semilavado|1500|2026|2026-08-04|60.000"""

ROASTS_TABLE = """
1|GL-2026-005|2026-06-03 09:00|12.000|10.200|15.00|660|207.5|medium
2|GL-2026-009|2026-06-03 10:30|10.000|8.600|14.00|600|202.0|light
3|GL-2026-011|2026-06-17 09:00|8.000|6.960|13.00|570|199.5|light
4|GL-2025-001|2026-06-17 10:30|15.000|12.600|16.00|720|212.0|medium
5|GL-2026-013|2026-07-01 09:00|5.000|4.350|13.00|540|198.0|light
6|GL-2025-002|2026-07-01 10:30|15.000|12.450|17.00|780|222.0|dark
7|GL-2026-006|2026-07-15 09:00|12.000|10.140|15.50|660|208.0|medium
8|GL-2026-015|2026-07-15 10:30|10.000|8.650|13.50|600|201.5|light
9|GL-2025-004|2026-07-29 09:00|12.000|10.200|15.00|650|206.0|medium
10|GL-2026-012|2026-08-05 09:00|10.000|8.500|15.00|590|200.0|light
11|GL-2025-001|2026-08-05 10:30|15.000|12.600|16.00|720|213.0|medium
12|GL-2026-016|2026-08-19 09:00|10.000|8.300|17.00|750|220.5|dark
13|GL-2026-013|2026-08-19 10:30|5.000|4.375|12.50|540|198.5|light
14|GL-2026-008|2026-08-26 09:00|8.000|6.840|14.50|610|204.0|medium
15|GL-2026-005|2026-09-02 09:00|12.000|10.140|15.50|660|208.0|medium
16|GL-2025-002|2026-09-02 10:30|15.000|12.375|17.50|790|223.0|dark
17|GL-2026-011|2026-09-16 09:00|8.000|6.960|13.00|570|200.0|light
18|GL-2026-013|2026-09-16 10:30|5.000|4.350|13.00|540|198.0|light
19|GL-2026-003|2026-09-30 09:00|12.000|10.200|15.00|650|209.0|medium
20|GL-2026-009|2026-10-01 09:00|10.000|8.600|14.00|600|202.5|light
21|GL-2025-001|2026-10-01 10:30|15.000|12.600|16.00|720|212.5|medium
22|GL-2026-012|2026-10-07 09:00|10.000|8.500|15.00|590|200.5|light
23|GL-2026-016|2026-10-07 10:30|10.000|8.250|17.50|760|221.0|dark
24|GL-2026-006|2026-10-09 09:00|12.000|10.200|15.00|650|207.0|medium"""

STOCK_AFTER = {
    "GL-2025-001": "75.000", "GL-2025-002": "150.000", "GL-2025-004": "128.000",
    "GL-2026-003": "57.000", "GL-2026-005": "45.000", "GL-2026-006": "114.000",
    "GL-2026-008": "26.500", "GL-2026-009": "49.000", "GL-2026-011": "44.000",
    "GL-2026-012": "100.000", "GL-2026-013": "0.000", "GL-2026-015": "50.000",
    "GL-2026-016": "40.000",
}
LOT_NOTE = "Lote de ejemplo cargado al iniciar BrewTrack."
ROAST_NOTE = "Tueste de ejemplo cargado al iniciar BrewTrack."
BA = ZoneInfo("America/Argentina/Buenos_Aires")


def _rows(table: str) -> list[list[str]]:
    return [[c.strip() for c in line.split("|")] for line in table.strip().splitlines()]


LOT_ROWS = _rows(LOTS_TABLE)
ROAST_ROWS = _rows(ROASTS_TABLE)


@pytest.fixture
def seed_on(monkeypatch):
    monkeypatch.setattr(settings, "seed_demo_lots", True)


def boot() -> None:
    """Arranca la API (corre el lifespan) y la apaga."""
    with TestClient(app):
        pass


def lots(db):
    db.expire_all()
    return {x.code: x for x in db.scalars(select(GreenLot))}


def count(db, model) -> int:
    db.expire_all()
    return db.scalar(select(func.count()).select_from(model))


@pytest.fixture
def info(caplog):
    caplog.set_level(logging.INFO)
    return lambda: caplog.text


@pytest.fixture
def seeded_lots(seed_on, db):
    boot()
    return db


@pytest.fixture
def full(seeded_lots, make_user, db):
    """CA-9: lotes cargados y luego create-admin con los 24 tuestes."""
    cli.create_admin("boss@x.com", "Boss", "longenough1")
    return db


# --- lotes ---

def test_ca1_ca2_ca32_seeds_20_lots(seed_on, db, info):
    boot()
    got = lots(db)
    assert len(got) == 20 and count(db, Roast) == 0
    assert "Se cargaron 20 lotes de ejemplo" in info()
    for code, country, region, farm, producer, variety, process, alt, hy, rec, kg in LOT_ROWS:
        lot = got[code]
        assert (lot.origin_country, lot.region, lot.farm, lot.producer) == (country, region, farm, producer)
        assert (lot.variety, lot.process) == (variety, process)
        assert lot.altitude_m == (None if alt.startswith("(") else int(alt))
        assert lot.harvest_year == int(hy) and lot.received_at == date.fromisoformat(rec)
        assert lot.received_kg == Decimal(kg) and lot.notes == LOT_NOTE
    assert sum(x.received_kg for x in got.values()) == Decimal("1502.000")
    assert len({x.origin_country for x in got.values()}) == 13
    assert len({x.process for x in got.values()}) == 5
    assert sum(x.altitude_m is None for x in got.values()) == 1


def test_ca3_restart_keeps_lots(seed_on, db, info):
    boot()
    before = {c: (x.id, x.updated_at) for c, x in lots(db).items()}
    boot()
    assert {c: (x.id, x.updated_at) for c, x in lots(db).items()} == before
    assert "Carga de lotes de ejemplo omitida: la base ya tiene lotes" in info()


def test_ca4_real_lot_blocks_seed(seed_on, db, make_lot, info):
    make_lot("GL-2026-900")
    boot()
    got = lots(db)
    assert list(got) == ["GL-2026-900"] and got["GL-2026-900"].received_kg == 60
    assert "Carga de lotes de ejemplo omitida: la base ya tiene lotes" in info()


def test_ca5_switch_off(monkeypatch, db, info):
    monkeypatch.setattr(settings, "seed_demo_lots", False)
    boot()
    assert count(db, GreenLot) == 0
    assert "Carga de datos de ejemplo desactivada" in info()


def test_ca6_default_is_off(db):
    assert settings.seed_demo_lots is False  # sin variable, pytest no carga nada
    boot()
    assert count(db, GreenLot) == 0


def test_ca7_failed_lot_load_is_all_or_nothing(seed_on, db, monkeypatch, info):
    real, n = seed.LotIn, []

    def flaky(**kw):
        n.append(1)
        if len(n) == 11:
            raise RuntimeError("boom")
        return real(**kw)

    monkeypatch.setattr(seed, "LotIn", flaky)
    with TestClient(app) as c:
        assert c.get("/api/v1/health").status_code == 200
    assert count(db, GreenLot) == 0
    assert "Error en la carga de lotes de ejemplo" in info() and "boom" in info()


def test_ca8_lots_pass_post_rules():
    for row in seed.LOTS:
        keys = "code origin_country region farm producer variety process altitude_m harvest_year received_at received_kg".split()
        LotIn(**dict(zip(keys, row)))


# --- tuestes ---

def test_ca9_ca10_ca22_create_admin_seeds_roasts(seeded_lots, db, capsys):
    cli.create_admin("boss@x.com", "Boss", "longenough1")
    assert "Se cargaron 24 tuestes de ejemplo" in capsys.readouterr().out
    admin = db.scalar(select(User))
    assert count(db, User) == 1
    roasts = db.scalars(select(Roast).order_by(Roast.roasted_at)).all()
    assert len(roasts) == 24 and {r.roaster_id for r in roasts} == {admin.id}
    # El orden de la spec es cronológico, igual que roasted_at.
    for r, (n, code, at, gin, gout, merma, dur, drop, level) in zip(roasts, ROAST_ROWS):
        assert r.lot.code == code
        assert r.roasted_at == datetime.fromisoformat(at).replace(tzinfo=BA)
        assert (r.green_in_kg, r.roasted_out_kg) == (Decimal(gin), Decimal(gout))
        assert (r.duration_s, r.drop_temp_c, r.roast_level) == (int(dur), Decimal(drop), level)
        assert r.loss_pct == Decimal(merma) and r.notes == ROAST_NOTE
    assert sum(r.green_in_kg for r in roasts) == Decimal("256.000")
    assert sorted(r.roast_level for r in roasts).count("dark") == 4


def test_ca11_boot_seeds_roasts_when_user_exists(seed_on, db, make_user):
    boot()
    make_user("a@x.com", "admin")
    boot()
    assert count(db, Roast) == 24


def test_ca12_new_db_with_user(seed_on, db, make_user):
    make_user("a@x.com", "admin")
    boot()
    assert count(db, GreenLot) == 20 and count(db, Roast) == 24


def test_ca13_no_users(seeded_lots, db, info):
    boot()
    assert count(db, Roast) == 0
    assert "Carga de tuestes de ejemplo omitida: no hay usuarios activos" in info()


def test_ca13_inactive_user_does_not_count(seeded_lots, db, make_user):
    make_user("a@x.com", "admin", active=False)
    boot()
    assert count(db, Roast) == 0


def test_ca14_idempotent(full, db, info):
    before = {r.id: (r.roaster_id, r.updated_at) for r in db.scalars(select(Roast))}
    boot()
    cli.create_admin("other@x.com", "Other", "longenough1")
    after = {r.id: (r.roaster_id, r.updated_at) for r in db.scalars(select(Roast))}
    assert after == before and len(after) == 24
    assert "Carga de tuestes de ejemplo omitida: la base ya tiene tuestes" in info()


def test_ca15_real_roast_blocks_seed(seeded_lots, db, make_user, make_roast):
    u = make_user("a@x.com", "admin")
    real = make_roast(lots(db)["GL-2026-001"], u)
    boot()
    got = db.scalars(select(Roast)).all()
    assert [r.id for r in got] == [real.id] and got[0].notes is None


def test_ca16_missing_lot(seeded_lots, db, make_user, info):
    make_user("a@x.com", "admin")
    db.delete(lots(db)["GL-2026-013"])
    db.commit()
    boot()
    assert count(db, Roast) == 0
    assert "Carga de tuestes de ejemplo omitida: faltan lotes de ejemplo" in info()


def test_ca16_lot_without_seed_note_counts_as_missing(seeded_lots, db, make_user):
    make_user("a@x.com", "admin")
    lots(db)["GL-2026-013"].notes = None
    db.commit()
    boot()
    assert count(db, Roast) == 0


def test_ca17_insufficient_stock(seeded_lots, db, make_user, info):
    make_user("a@x.com", "admin")
    lots(db)["GL-2026-013"].received_kg = Decimal("10.000")
    db.commit()
    boot()
    assert count(db, Roast) == 0
    assert "Carga de tuestes de ejemplo omitida: stock insuficiente" in info()


def test_ca18_off_in_create_admin(monkeypatch, db, capsys):
    monkeypatch.setattr(settings, "seed_demo_lots", False)
    cli.create_admin("boss@x.com", "Boss", "longenough1")
    assert count(db, User) == 1 and count(db, Roast) == 0
    assert "Carga de datos de ejemplo desactivada" in capsys.readouterr().out


def test_ca19_failed_roast_load_keeps_admin(seeded_lots, db, monkeypatch, capsys):
    real, n = seed.loss_pct, []

    def flaky(a, b):
        n.append(1)
        if len(n) == 12:
            raise RuntimeError("boom")
        return real(a, b)

    monkeypatch.setattr(seed, "loss_pct", flaky)
    monkeypatch.setattr("sys.argv", ["cli", "create-admin", "--email", "b@x.com"])
    monkeypatch.setattr("getpass.getpass", lambda _: "longenough1")
    cli.main()  # termina sin SystemExit: código 0
    assert count(db, User) == 1 and count(db, Roast) == 0
    out = capsys.readouterr().out
    assert "Error en la carga de tuestes de ejemplo" in out and "boom" in out


def test_ca20_oldest_active_user_is_author(seeded_lots, db, make_user):
    first = make_user("first@x.com", "roaster")
    make_user("second@x.com", "admin")
    boot()
    assert {r.roaster_id for r in db.scalars(select(Roast))} == {first.id}


def test_ca21_roasts_pass_post_rules(seeded_lots, db):
    got = lots(db)
    for code, at, gin, gout, dur, drop, level in seed.ROASTS:
        lot = got[code]
        RoastIn(
            lot_id=lot.id, roasted_at=datetime.fromisoformat(at).replace(tzinfo=BA),
            green_in_kg=gin, roasted_out_kg=gout, duration_s=dur, drop_temp_c=drop, roast_level=level,
        )
        assert datetime.fromisoformat(at).date() > lot.received_at


# --- datos visibles ---

def test_ca23_ca31_lots_listing(seeded_lots, roaster, auth, client):
    r = client.get("/api/v1/green-lots?limit=50", headers=auth(roaster))
    assert r.status_code == 200 and r.json()["total"] == 20
    assert all(i["stock_kg"] == i["received_kg"] for i in r.json()["items"])
    r = client.get("/api/v1/green-lots?country=Etiopía", headers=auth(roaster))
    assert r.json()["total"] == 2


def test_ca24_stock_after_roasts(full, db, roaster, auth, client):
    items = client.get("/api/v1/green-lots?limit=50", headers=auth(roaster)).json()["items"]
    assert len(items) == 20 and all(i["stock_kg"] >= 0 for i in items)
    for i in items:
        want = Decimal(STOCK_AFTER.get(i["code"], str(i["received_kg"])))
        assert Decimal(str(i["stock_kg"])) == want


def test_ca25_ca26_summary(full, roaster, auth, client, monkeypatch):
    monkeypatch.setattr(settings, "timezone", "America/Argentina/Buenos_Aires")
    s = client.get("/api/v1/stats/summary?month=2026-10", headers=auth(roaster)).json()
    assert s["lots_in_stock"] == 19 and s["stock_kg"] == "1246.000"
    assert s["roasted"] == {"roasts": 5, "green_kg": "57.000", "roasted_kg": "48.150"}
    assert s["loss_pct"] == "15.53"
    s = client.get("/api/v1/stats/summary?month=2026-09", headers=auth(roaster)).json()
    assert s["roasted"] == {"roasts": 5, "green_kg": "52.000", "roasted_kg": "44.025"}
    assert s["loss_pct"] == "15.34"


def test_ca27_no_token(full, client):
    for path in ("green-lots", "roasts"):
        r = client.get(f"/api/v1/{path}")
        assert r.status_code == 401 and set(r.json()["error"]) == {"code", "message"}


def test_ca28_ca29_roast_permissions(full, db, roaster, admin, auth, client):
    rid = db.scalars(select(Roast)).first().id
    r = client.patch(f"/api/v1/roasts/{rid}", json={"notes": "x"}, headers=auth(roaster))
    assert r.status_code == 403 and set(r.json()["error"]) == {"code", "message"}
    r = client.delete(f"/api/v1/roasts/{rid}", headers=auth(roaster))
    assert r.status_code == 403 and set(r.json()["error"]) == {"code", "message"}
    assert client.delete(f"/api/v1/roasts/{rid}", headers=auth(admin)).status_code == 204
    assert count(db, Roast) == 23


def test_ca30_lot_with_roasts_not_deletable(full, db, admin, auth, client):
    lot = lots(db)["GL-2026-013"]
    r = client.delete(f"/api/v1/green-lots/{lot.id}", headers=auth(admin))
    assert r.status_code == 409 and set(r.json()["error"]) == {"code", "message"}


def test_ca32_log_lines_for_cases(seed_on, db, make_lot, info):
    make_lot("GL-2026-900")
    boot()
    assert "Carga de lotes de ejemplo omitida: la base ya tiene lotes" in info()
