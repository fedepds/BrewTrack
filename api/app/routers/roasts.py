import uuid
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal
from typing import Literal

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field, model_validator
from sqlalchemy import exists, func, select
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import admin_only, current_user
from app.errors import ApiError
from app.models import GreenLot, Roast, RoastWithdrawal, User
from app.schemas import Page, RoastDetail, RoastOut, WithdrawalOut
from app.stock import used_kg, withdrawn_kg

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


class WithdrawalIn(BaseModel):
    withdrawn_at: datetime
    kg: Decimal = Field(**Kg)
    reason: Literal["sale", "consumption", "other"]
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
    # of=Roast: los joined (lote, tostador) usan LEFT JOIN y Postgres rechaza FOR UPDATE sobre ellos
    roast = db.get(Roast, roast_id, with_for_update={"of": Roast})
    if not roast:
        raise ApiError(404, "not_found", "Tueste no encontrado")
    if user.role != "admin" and roast.roaster_id != user.id:
        raise ApiError(403, "forbidden", "Solo el autor o un admin puede editar este tueste")
    changes = body.model_dump(exclude_unset=True)
    new_in = changes.get("green_in_kg", roast.green_in_kg)
    new_out = changes.get("roasted_out_kg", roast.roasted_out_kg)
    if new_out > new_in:
        raise ApiError(422, "validation_error", "roasted_out_kg no puede superar green_in_kg")
    if new_out < withdrawn_kg(db, roast.id):
        raise ApiError(409, "insufficient_roasted_stock", "roasted_out_kg es menor que lo ya retirado")
    lot = db.get(GreenLot, roast.lot_id, with_for_update=True)
    _check_stock(db, lot, new_in, exclude=roast.id)
    for k, v in changes.items():
        setattr(roast, k, v)
    roast.loss_pct = loss_pct(new_in, new_out)
    db.commit()
    db.refresh(roast)
    return roast


@router.delete("/{roast_id}", status_code=204, dependencies=[Depends(admin_only)])
def delete_roast(roast_id: uuid.UUID, db: Session = Depends(get_db)):
    roast = _roast_or_404(db, roast_id)
    if db.scalar(select(exists().where(RoastWithdrawal.roast_id == roast.id))):
        raise ApiError(409, "roast_has_withdrawals", "El tueste tiene salidas y no se puede borrar")
    db.delete(roast)
    db.commit()


@router.get("/{roast_id}/withdrawals", response_model=list[WithdrawalOut])
def list_withdrawals(roast_id: uuid.UUID, db: Session = Depends(get_db)):
    return _roast_or_404(db, roast_id).withdrawals


@router.post("/{roast_id}/withdrawals", response_model=WithdrawalOut, status_code=201)
def create_withdrawal(
    roast_id: uuid.UUID, body: WithdrawalIn, user: User = Depends(current_user), db: Session = Depends(get_db)
):
    roast = db.get(Roast, roast_id, with_for_update={"of": Roast})  # serializa salidas del mismo tueste
    if not roast:
        raise ApiError(404, "not_found", "Tueste no encontrado")
    available = roast.roasted_out_kg - withdrawn_kg(db, roast.id)
    if body.kg > available:
        raise ApiError(409, "insufficient_roasted_stock", f"Stock tostado disponible: {available} kg")
    w = RoastWithdrawal(**body.model_dump(), roast_id=roast.id, user_id=user.id)
    db.add(w)
    db.commit()
    db.refresh(w)
    return w


@router.delete("/{roast_id}/withdrawals/{withdrawal_id}", status_code=204, dependencies=[Depends(admin_only)])
def delete_withdrawal(roast_id: uuid.UUID, withdrawal_id: uuid.UUID, db: Session = Depends(get_db)):
    w = db.get(RoastWithdrawal, withdrawal_id)
    if not w or w.roast_id != roast_id:
        raise ApiError(404, "not_found", "Salida no encontrada")
    db.delete(w)
    db.commit()
