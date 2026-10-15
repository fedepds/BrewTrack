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
