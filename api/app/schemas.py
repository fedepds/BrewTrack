import uuid
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, PlainSerializer

# Decimal en BD, número JSON hacia el cliente.
Num = Annotated[Decimal, PlainSerializer(float, return_type=float, when_used="json")]


class ORM(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class UserOut(ORM):
    id: uuid.UUID
    email: str
    name: str
    role: Literal["roaster", "admin"]
    active: bool
