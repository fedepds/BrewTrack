import uuid
from typing import Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import admin_only
from app.errors import ApiError, commit_or_409
from app.models import User
from app.schemas import UserOut
from app.security import hash_password

router = APIRouter(prefix="/users", tags=["users"], dependencies=[Depends(admin_only)])

Role = Literal["roaster", "admin"]


class UserIn(BaseModel):
    email: EmailStr
    name: str = Field(min_length=1, max_length=120)
    password: str = Field(min_length=8, max_length=128)
    role: Role


class UserPatch(BaseModel):
    # default=None sin "| None": omitir el campo lo ignora, enviar null es 422.
    name: str = Field(default=None, min_length=1, max_length=120)
    password: str = Field(default=None, min_length=8, max_length=128)
    role: Role = None
    active: bool = None


@router.get("", response_model=list[UserOut])
def list_users(db: Session = Depends(get_db)):
    return db.scalars(select(User).order_by(User.email)).all()


@router.post("", response_model=UserOut, status_code=201)
def create_user(body: UserIn, db: Session = Depends(get_db)):
    user = User(
        email=body.email.lower(), name=body.name, role=body.role,
        password_hash=hash_password(body.password),
    )
    db.add(user)
    commit_or_409(db, "duplicate_email", "Ya existe un usuario con ese email")
    return user


@router.patch("/{user_id}", response_model=UserOut)
def patch_user(user_id: uuid.UUID, body: UserPatch, db: Session = Depends(get_db)):
    user = db.get(User, user_id)
    if not user:
        raise ApiError(404, "not_found", "Usuario no encontrado")
    changes = body.model_dump(exclude_unset=True)
    demoting = changes.get("active") is False or changes.get("role") == "roaster"
    if user.role == "admin" and user.active and demoting:
        admins = db.scalar(
            select(func.count()).select_from(User).where(User.role == "admin", User.active)
        )
        if admins <= 1:
            raise ApiError(409, "last_admin", "No se puede desactivar o degradar al último admin")
    if "password" in changes:
        user.password_hash = hash_password(changes.pop("password"))
    for k, v in changes.items():
        setattr(user, k, v)
    db.commit()
    return user
