import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint, Date, DateTime, ForeignKey, Index, Numeric, String, Text, Uuid, func, select, true,
)
from sqlalchemy.orm import Mapped, column_property, mapped_column, relationship

from app.db import Base


class Timestamps:
    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class User(Base, Timestamps):
    __tablename__ = "users"
    email: Mapped[str] = mapped_column(String(255), unique=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    name: Mapped[str] = mapped_column(String(120))
    role: Mapped[str] = mapped_column(String(20))
    active: Mapped[bool] = mapped_column(default=True, server_default=true())
    __table_args__ = (CheckConstraint("role IN ('roaster','admin')", name="ck_users_role"),)


class GreenLot(Base, Timestamps):
    __tablename__ = "green_lots"
    code: Mapped[str] = mapped_column(String(40), unique=True)
    origin_country: Mapped[str] = mapped_column(String(80))
    region: Mapped[str | None] = mapped_column(String(120))
    farm: Mapped[str | None] = mapped_column(String(120))
    producer: Mapped[str | None] = mapped_column(String(120))
    variety: Mapped[str] = mapped_column(String(120))
    process: Mapped[str] = mapped_column(String(60))
    altitude_m: Mapped[int | None]
    harvest_year: Mapped[int]
    received_at: Mapped[date] = mapped_column(Date)
    received_kg: Mapped[Decimal] = mapped_column(Numeric(10, 3))
    notes: Mapped[str | None] = mapped_column(Text)
    roasts: Mapped[list["Roast"]] = relationship(
        back_populates="lot", order_by="Roast.roasted_at.desc()"
    )
    __table_args__ = (CheckConstraint("received_kg > 0", name="ck_lots_received_kg"),)


class Roast(Base, Timestamps):
    __tablename__ = "roasts"
    lot_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("green_lots.id", ondelete="RESTRICT"))
    roaster_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"))
    roasted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    green_in_kg: Mapped[Decimal] = mapped_column(Numeric(10, 3))
    roasted_out_kg: Mapped[Decimal] = mapped_column(Numeric(10, 3))
    loss_pct: Mapped[Decimal] = mapped_column(Numeric(5, 2))
    duration_s: Mapped[int]
    drop_temp_c: Mapped[Decimal] = mapped_column(Numeric(5, 1))
    roast_level: Mapped[str] = mapped_column(String(10))
    notes: Mapped[str | None] = mapped_column(Text)
    lot: Mapped[GreenLot] = relationship(back_populates="roasts", lazy="joined")
    roaster: Mapped[User] = relationship(lazy="joined")

    @property
    def lot_code(self) -> str:
        return self.lot.code

    @property
    def roaster_name(self) -> str:
        return self.roaster.name

    __table_args__ = (
        CheckConstraint("green_in_kg > 0", name="ck_roasts_green_in"),
        CheckConstraint("roasted_out_kg > 0 AND roasted_out_kg <= green_in_kg", name="ck_roasts_out"),
        CheckConstraint("duration_s > 0", name="ck_roasts_duration"),
        CheckConstraint("roast_level IN ('light','medium','dark')", name="ck_roasts_level"),
        Index("ix_roasts_lot_id", "lot_id"),
        Index("ix_roasts_roasted_at", "roasted_at"),
    )


# Stock: única expresión de lectura. Se calcula en cada consulta; nunca se guarda.
GreenLot.stock_kg = column_property(
    GreenLot.received_kg
    - select(func.coalesce(func.sum(Roast.green_in_kg), 0))
    .where(Roast.lot_id == GreenLot.id)
    .correlate_except(Roast)
    .scalar_subquery()
)
