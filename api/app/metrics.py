"""Métricas de negocio para Prometheus (spec 009). Se publican en /metrics junto a las HTTP."""

import logging
from collections.abc import Iterator
from decimal import Decimal

from prometheus_client import REGISTRY, Counter
from prometheus_client.core import GaugeMetricFamily
from prometheus_client.registry import Collector
from sqlalchemy import func, select

from app.db import SessionLocal
from app.models import GreenLot, Roast

log = logging.getLogger("uvicorn.error")

# Contadores: cuentan desde que arrancó el proceso. Prometheus calcula tasas con rate()/increase()
# y tolera que vuelvan a cero cuando el pod se reinicia.
ROASTS_CREATED = Counter(
    "brewtrack_roasts_created", "Tuestes registrados por la API", ["roast_level"]
)
ROAST_GREEN_IN_KG = Counter(
    "brewtrack_roast_green_in_kg", "Kg de café verde que entraron al tostador en tuestes nuevos"
)
ROAST_OUT_KG = Counter(
    "brewtrack_roast_out_kg", "Kg de café tostado que salieron del tostador en tuestes nuevos"
)


def record_roast(roast_level: str, green_in_kg: Decimal, roasted_out_kg: Decimal) -> None:
    ROASTS_CREATED.labels(roast_level=roast_level).inc()
    ROAST_GREEN_IN_KG.inc(float(green_in_kg))
    ROAST_OUT_KG.inc(float(roasted_out_kg))


class StockCollector(Collector):
    """Calcula el stock verde en cada scrape. No lo guarda: sigue la regla de la constitución."""

    def collect(self) -> Iterator[GaugeMetricFamily]:
        try:
            with SessionLocal() as db:
                received = db.scalar(select(func.coalesce(func.sum(GreenLot.received_kg), 0)))
                used = db.scalar(select(func.coalesce(func.sum(Roast.green_in_kg), 0)))
                lots = db.scalar(select(func.count()).select_from(GreenLot).where(GreenLot.stock_kg > 0))
        except Exception:  # noqa: BLE001 — sin base, /metrics sigue respondiendo las métricas HTTP.
            log.warning("métricas de negocio: no se pudo leer la base")
            return
        yield GaugeMetricFamily(
            "brewtrack_green_stock_kg", "Kg de café verde disponibles en todos los lotes", value=float(received - used)
        )
        yield GaugeMetricFamily(
            "brewtrack_green_lots_with_stock", "Lotes de café verde con stock mayor a cero", value=lots
        )


REGISTRY.register(StockCollector())
