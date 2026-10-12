"""Carga de lotes y tuestes de ejemplo (spec 002). No crea usuarios ni toca datos existentes."""
from datetime import date, datetime
from decimal import Decimal
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.db import SessionLocal
from app.errors import ApiError
from app.models import GreenLot, Roast, User
from app.routers.green_lots import LotIn
from app.routers.roasts import RoastIn, _check_stock, loss_pct

LOT_NOTE = "Lote de ejemplo cargado al iniciar BrewTrack."
ROAST_NOTE = "Tueste de ejemplo cargado al iniciar BrewTrack."
DISABLED = "Carga de datos de ejemplo desactivada"
# Instantes fijos: no dependen de TIMEZONE.
SEED_TZ = ZoneInfo("America/Argentina/Buenos_Aires")

# code, país, región, finca, productor, variedad, proceso, altitud, cosecha, recepción, kg
LOTS = [
    ("GL-2025-001", "Brasil", "Sul de Minas", "Fazenda Santa Inês", "Família Pereira", "Yellow Bourbon", "Natural", 1100, 2025, "2025-11-11", "120.000"),
    ("GL-2025-002", "Brasil", "Cerrado Mineiro", "Fazenda Boa Vista", "Família Costa", "Mundo Novo", "Despulpado natural", None, 2025, "2025-11-11", "180.000"),
    ("GL-2025-003", "Colombia", "Huila", "La Esperanza", "Familia Rojas", "Caturra", "Lavado", 1750, 2025, "2025-12-02", "70.000"),
    ("GL-2025-004", "Colombia", "Nariño", "El Mirador", "Asociación de Productores de Buesaco", "Castillo", "Lavado", 2100, 2025, "2025-12-02", "140.000"),
    ("GL-2026-001", "Colombia", "Cauca", "Las Brisas", "Hernán Muñoz", "Pink Bourbon", "Honey", 1850, 2025, "2026-01-13", "35.000"),
    ("GL-2026-002", "Bolivia", "Caranavi", "Finca Illimani", "Familia Mamani", "Java", "Natural", 1650, 2025, "2026-02-17", "69.000"),
    ("GL-2026-003", "Perú", "Cajamarca", "El Huabo", "Cooperativa de San Ignacio", "Bourbon, Typica", "Lavado", 1800, 2025, "2026-02-17", "69.000"),
    ("GL-2026-004", "Ruanda", "Nyamasheke", "Estación Muhondo", "Cooperativa de Nyamasheke", "Red Bourbon", "Lavado", 1800, 2025, "2026-03-10", "60.000"),
    ("GL-2026-005", "Guatemala", "Huehuetenango", "Finca Los Altos", "Familia Villatoro", "Bourbon, Caturra", "Lavado", 1800, 2026, "2026-04-14", "69.000"),
    ("GL-2026-006", "Guatemala", "Antigua", "Finca San Rafael", "Familia Zelaya", "Bourbon", "Lavado", 1600, 2026, "2026-04-14", "138.000"),
    ("GL-2026-007", "Honduras", "Marcala", "El Cedro", "Cooperativa de Marcala", "Catuaí", "Lavado", 1500, 2026, "2026-04-28", "69.000"),
    ("GL-2026-008", "El Salvador", "Santa Ana", "Finca Los Naranjos", "Familia Aguilar", "Pacamara", "Honey", 1650, 2026, "2026-04-28", "34.500"),
    ("GL-2026-009", "Costa Rica", "Tarrazú", "Finca El Llano", "Familia Solís", "Caturra, Catuaí", "Honey", 1700, 2026, "2026-05-12", "69.000"),
    ("GL-2026-010", "Costa Rica", "Valle Occidental", "Finca Alto Naranjo", "Familia Vargas", "Villa Sarchí", "Natural", 1500, 2026, "2026-05-12", "34.500"),
    ("GL-2026-011", "Etiopía", "Yirgacheffe", "Estación Konga", "Cooperativa Konga", "Heirloom etíope", "Lavado", 2000, 2026, "2026-05-26", "60.000"),
    ("GL-2026-012", "Etiopía", "Guji", "Estación Hambela", "Productores de Hambela", "Heirloom etíope", "Natural", 2150, 2026, "2026-05-26", "120.000"),
    ("GL-2026-013", "Panamá", "Boquete", "Finca Las Nubes", "Familia Serracín", "Geisha", "Lavado", 1700, 2026, "2026-06-09", "15.000"),
    ("GL-2026-014", "Panamá", "Volcán", "Finca Cerro Punta", "Familia Araúz", "Catuaí", "Natural", 1500, 2026, "2026-06-09", "30.000"),
    ("GL-2026-015", "Kenia", "Nyeri", "Gaturiri", "Cooperativa de Gaturiri", "SL28, SL34", "Lavado", 1750, 2025, "2026-07-07", "60.000"),
    ("GL-2026-016", "Indonesia", "Aceh (Gayo)", "Lago Tawar", "Cooperativa Gayo", "Ateng, Tim Tim", "Semilavado", 1500, 2026, "2026-08-04", "60.000"),
]

# lote, tostado (hora de Buenos Aires), verde kg, tostado kg, duración s, descarga °C, nivel
ROASTS = [
    ("GL-2026-005", "2026-06-03 09:00", "12.000", "10.200", 660, "207.5", "medium"),
    ("GL-2026-009", "2026-06-03 10:30", "10.000", "8.600", 600, "202.0", "light"),
    ("GL-2026-011", "2026-06-17 09:00", "8.000", "6.960", 570, "199.5", "light"),
    ("GL-2025-001", "2026-06-17 10:30", "15.000", "12.600", 720, "212.0", "medium"),
    ("GL-2026-013", "2026-07-01 09:00", "5.000", "4.350", 540, "198.0", "light"),
    ("GL-2025-002", "2026-07-01 10:30", "15.000", "12.450", 780, "222.0", "dark"),
    ("GL-2026-006", "2026-07-15 09:00", "12.000", "10.140", 660, "208.0", "medium"),
    ("GL-2026-015", "2026-07-15 10:30", "10.000", "8.650", 600, "201.5", "light"),
    ("GL-2025-004", "2026-07-29 09:00", "12.000", "10.200", 650, "206.0", "medium"),
    ("GL-2026-012", "2026-08-05 09:00", "10.000", "8.500", 590, "200.0", "light"),
    ("GL-2025-001", "2026-08-05 10:30", "15.000", "12.600", 720, "213.0", "medium"),
    ("GL-2026-016", "2026-08-19 09:00", "10.000", "8.300", 750, "220.5", "dark"),
    ("GL-2026-013", "2026-08-19 10:30", "5.000", "4.375", 540, "198.5", "light"),
    ("GL-2026-008", "2026-08-26 09:00", "8.000", "6.840", 610, "204.0", "medium"),
    ("GL-2026-005", "2026-09-02 09:00", "12.000", "10.140", 660, "208.0", "medium"),
    ("GL-2025-002", "2026-09-02 10:30", "15.000", "12.375", 790, "223.0", "dark"),
    ("GL-2026-011", "2026-09-16 09:00", "8.000", "6.960", 570, "200.0", "light"),
    ("GL-2026-013", "2026-09-16 10:30", "5.000", "4.350", 540, "198.0", "light"),
    ("GL-2026-003", "2026-09-30 09:00", "12.000", "10.200", 650, "209.0", "medium"),
    ("GL-2026-009", "2026-10-01 09:00", "10.000", "8.600", 600, "202.5", "light"),
    ("GL-2025-001", "2026-10-01 10:30", "15.000", "12.600", 720, "212.5", "medium"),
    ("GL-2026-012", "2026-10-07 09:00", "10.000", "8.500", 590, "200.5", "light"),
    ("GL-2026-016", "2026-10-07 10:30", "10.000", "8.250", 760, "221.0", "dark"),
    ("GL-2026-006", "2026-10-09 09:00", "12.000", "10.200", 650, "207.0", "medium"),
]

def seed_lots(db: Session) -> str:
    """Todo o nada: valida con LotIn y confirma una sola vez."""
    if db.scalar(select(GreenLot.id).limit(1)):
        return "Carga de lotes de ejemplo omitida: la base ya tiene lotes"
    keys = ("code origin_country region farm producer variety process altitude_m harvest_year "
            "received_at received_kg").split()
    for row in LOTS:
        data = LotIn(**dict(zip(keys, row)), notes=LOT_NOTE).model_dump()
        db.add(GreenLot(**data))
    db.commit()
    return f"Se cargaron {len(LOTS)} lotes de ejemplo"


def seed_roasts(db: Session) -> str:
    skip = "Carga de tuestes de ejemplo omitida: "
    if db.scalar(select(Roast.id).limit(1)):
        return skip + "la base ya tiene tuestes"
    author = db.scalar(
        select(User).where(User.active).order_by(User.created_at, User.id).limit(1)
    )
    if not author:
        return skip + "no hay usuarios activos"
    codes = {r[0] for r in ROASTS}
    lots = {
        lot.code: lot
        for lot in db.scalars(
            select(GreenLot).where(GreenLot.code.in_(codes), GreenLot.notes == LOT_NOTE)
        )
    }
    if len(lots) != len(codes):
        return skip + "faltan lotes de ejemplo"
    try:
        for code, at, gin, gout, dur, drop, level in ROASTS:
            body = RoastIn(
                lot_id=lots[code].id,
                roasted_at=datetime.fromisoformat(at).replace(tzinfo=SEED_TZ),
                green_in_kg=Decimal(gin), roasted_out_kg=Decimal(gout), duration_s=dur,
                drop_temp_c=Decimal(drop), roast_level=level, notes=ROAST_NOTE,
            )
            _check_stock(db, lots[code], body.green_in_kg)  # cuenta los tuestes ya agregados
            db.add(Roast(
                **body.model_dump(), roaster_id=author.id,
                loss_pct=loss_pct(body.green_in_kg, body.roasted_out_kg),
            ))
            db.flush()
    except ApiError:
        db.rollback()
        return skip + "stock insuficiente"
    db.commit()
    return f"Se cargaron {len(ROASTS)} tuestes de ejemplo"


def _guarded(label: str, fn) -> str:
    """Una carga que falla deja la base como estaba y devuelve el error."""
    try:
        with SessionLocal() as db:
            return fn(db)
    except Exception as e:
        return f"Error en la carga de {label} de ejemplo: {type(e).__name__}: {e}"


def run_seed(lots: bool = True) -> list[str]:
    """Líneas de resultado. Nunca lanza. `lots=False` la usa create-admin."""
    if not settings.seed_demo_lots:
        return [DISABLED]
    out = [_guarded("lotes", seed_lots)] if lots else []
    return out + [_guarded("tuestes", seed_roasts)]
