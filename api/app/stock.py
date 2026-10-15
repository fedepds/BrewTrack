import uuid
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Roast


# Solo para validar antes de escribir (puede excluir un tueste). Para leer usa GreenLot.stock_kg.
def used_kg(db: Session, lot_id: uuid.UUID, exclude_roast_id: uuid.UUID | None = None) -> Decimal:
    q = select(func.coalesce(func.sum(Roast.green_in_kg), 0)).where(Roast.lot_id == lot_id)
    if exclude_roast_id:
        q = q.where(Roast.id != exclude_roast_id)
    return db.scalar(q)
