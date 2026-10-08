import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Annotated, Generic, Literal, TypeVar

from pydantic import BaseModel, ConfigDict, PlainSerializer

# Decimal en BD, número JSON hacia el cliente.
Num = Annotated[Decimal, PlainSerializer(float, return_type=float, when_used="json")]
T = TypeVar("T")


class ORM(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class Page(BaseModel, Generic[T]):
    items: list[T]
    total: int
    limit: int
    offset: int


class UserOut(ORM):
    id: uuid.UUID
    email: str
    name: str
    role: Literal["roaster", "admin"]
    active: bool


class LotOut(ORM):
    id: uuid.UUID
    code: str
    origin_country: str
    region: str | None
    farm: str | None
    producer: str | None
    variety: str
    process: str
    altitude_m: int | None
    harvest_year: int
    received_at: date
    received_kg: Num
    notes: str | None
    stock_kg: Num  # se asigna como atributo transitorio antes de serializar


class RoastOut(ORM):
    id: uuid.UUID
    lot_id: uuid.UUID
    lot_code: str
    roaster_id: uuid.UUID
    roaster_name: str
    roasted_at: datetime
    green_in_kg: Num
    roasted_out_kg: Num
    loss_pct: Num
    duration_s: int
    drop_temp_c: Num
    roast_level: Literal["light", "medium", "dark"]
    notes: str | None


class LotDetail(LotOut):
    roasts: list[RoastOut]
