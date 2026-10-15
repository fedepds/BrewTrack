import uuid
from datetime import date
from decimal import Decimal

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy import exists, func, select
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import admin_only, current_user
from app.errors import ApiError, commit_or_409
from app.models import GreenLot, Roast
from app.schemas import LotDetail, LotOut, Page
from app.stock import used_kg

router = APIRouter(prefix="/green-lots", tags=["green-lots"], dependencies=[Depends(current_user)])


class LotIn(BaseModel):
    code: str = Field(min_length=1, max_length=40)
    origin_country: str = Field(min_length=1, max_length=80)
    region: str | None = Field(None, max_length=120)
    farm: str | None = Field(None, max_length=120)
    producer: str | None = Field(None, max_length=120)
    variety: str = Field(min_length=1, max_length=120)
    process: str = Field(min_length=1, max_length=60)
    altitude_m: int | None = Field(None, gt=0, le=6000)
    harvest_year: int = Field(ge=1900, le=2100)
    received_at: date
    received_kg: Decimal = Field(gt=0, max_digits=10, decimal_places=3)
    notes: str | None = None


class LotPatch(BaseModel):
    # Campos obligatorios: default=None sin "| None" (omitir = ignorar, null = 422).
    code: str = Field(default=None, min_length=1, max_length=40)
    origin_country: str = Field(default=None, min_length=1, max_length=80)
    region: str | None = Field(None, max_length=120)
    farm: str | None = Field(None, max_length=120)
    producer: str | None = Field(None, max_length=120)
    variety: str = Field(default=None, min_length=1, max_length=120)
    process: str = Field(default=None, min_length=1, max_length=60)
    altitude_m: int | None = Field(None, gt=0, le=6000)
    harvest_year: int = Field(default=None, ge=1900, le=2100)
    received_at: date = None
    received_kg: Decimal = Field(default=None, gt=0, max_digits=10, decimal_places=3)
    notes: str | None = None


def _lot_or_404(db: Session, lot_id: uuid.UUID, lock: bool = False) -> GreenLot:
    lot = db.get(GreenLot, lot_id, with_for_update=lock or None)
    if not lot:
        raise ApiError(404, "not_found", "Lote no encontrado")
    return lot


@router.get("", response_model=Page[LotOut])
def list_lots(
    country: str | None = None,
    process: str | None = None,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    where = []
    if country:
        where.append(GreenLot.origin_country.ilike(f"%{country}%"))
    if process:
        where.append(GreenLot.process.ilike(f"%{process}%"))
    rows = db.scalars(
        select(GreenLot).where(*where)
        .order_by(GreenLot.received_at.desc(), GreenLot.code).limit(limit).offset(offset)
    ).all()
    total = db.scalar(select(func.count()).select_from(GreenLot).where(*where))
    return Page[LotOut](
        items=[LotOut.model_validate(lot) for lot in rows], total=total, limit=limit, offset=offset
    )


@router.get("/{lot_id}", response_model=LotDetail)
def get_lot(lot_id: uuid.UUID, db: Session = Depends(get_db)):
    return _lot_or_404(db, lot_id)


@router.post("", response_model=LotOut, status_code=201)
def create_lot(body: LotIn, db: Session = Depends(get_db)):
    lot = GreenLot(**body.model_dump())
    db.add(lot)
    commit_or_409(db, "duplicate_code", "Ya existe un lote con ese código")
    db.refresh(lot)  # relee también el stock calculado
    return lot


@router.patch("/{lot_id}", response_model=LotOut)
def patch_lot(lot_id: uuid.UUID, body: LotPatch, db: Session = Depends(get_db)):
    lot = _lot_or_404(db, lot_id, lock=True)
    changes = body.model_dump(exclude_unset=True)
    if "received_kg" in changes and changes["received_kg"] < used_kg(db, lot.id):
        raise ApiError(409, "insufficient_stock", "received_kg es menor que lo ya tostado")
    for k, v in changes.items():
        setattr(lot, k, v)
    commit_or_409(db, "duplicate_code", "Ya existe un lote con ese código")
    db.refresh(lot)
    return lot


@router.delete("/{lot_id}", status_code=204, dependencies=[Depends(admin_only)])
def delete_lot(lot_id: uuid.UUID, db: Session = Depends(get_db)):
    lot = _lot_or_404(db, lot_id)
    if db.scalar(select(exists().where(Roast.lot_id == lot.id))):
        raise ApiError(409, "lot_has_roasts", "El lote tiene tuestes y no se puede borrar")
    db.delete(lot)
    db.commit()
