from datetime import date, datetime, time
from decimal import ROUND_HALF_UP, Decimal
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import settings
from app.db import get_db
from app.deps import current_user
from app.models import GreenLot, Roast

router = APIRouter(prefix="/stats", tags=["stats"], dependencies=[Depends(current_user)])

# Años 1900–2099: evita que date() falle con 0000 o 9999-12.
MONTH = r"^(19|20)\d{2}-(0[1-9]|1[0-2])$"


class Received(BaseModel):
    lots: int
    kg: str


class Roasted(BaseModel):
    roasts: int
    green_kg: str
    roasted_kg: str


class Summary(BaseModel):
    month: str
    lots_in_stock: int
    stock_kg: str
    received: Received
    roasted: Roasted
    loss_pct: str | None


def _kg(v: Decimal) -> str:
    return str(Decimal(v).quantize(Decimal("0.001")))


@router.get("/summary", response_model=Summary)
def summary(month: str | None = Query(None, pattern=MONTH), db: Session = Depends(get_db)) -> Summary:
    tz = ZoneInfo(settings.timezone)
    month = month or datetime.now(tz).strftime("%Y-%m")
    y, m = map(int, month.split("-"))
    start, end = date(y, m, 1), date(y + m // 12, m % 12 + 1, 1)
    start_at, end_at = datetime.combine(start, time(), tz), datetime.combine(end, time(), tz)

    stock = GreenLot.stock_kg
    lots_in_stock, stock_total = db.execute(
        select(func.count().filter(stock > 0), func.coalesce(func.sum(stock), 0)).select_from(GreenLot)
    ).one()
    lots, received_kg = db.execute(
        select(func.count(), func.coalesce(func.sum(GreenLot.received_kg), 0))
        .where(GreenLot.received_at >= start, GreenLot.received_at < end)
    ).one()
    roasts, green_kg, roasted_kg = db.execute(
        select(
            func.count(),
            func.coalesce(func.sum(Roast.green_in_kg), 0),
            func.coalesce(func.sum(Roast.roasted_out_kg), 0),
        ).where(Roast.roasted_at >= start_at, Roast.roasted_at < end_at)
    ).one()

    loss = None
    if roasts:
        loss = str(((1 - roasted_kg / green_kg) * 100).quantize(Decimal("0.01"), ROUND_HALF_UP))
    return Summary(
        month=month,
        lots_in_stock=lots_in_stock,
        stock_kg=_kg(stock_total),
        received=Received(lots=lots, kg=_kg(received_kg)),
        roasted=Roasted(roasts=roasts, green_kg=_kg(green_kg), roasted_kg=_kg(roasted_kg)),
        loss_pct=loss,
    )
