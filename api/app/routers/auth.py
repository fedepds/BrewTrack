from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import current_user
from app.errors import ApiError
from app.models import User
from app.schemas import UserOut
from app.security import (
    create_access_token, create_refresh_token, decode_token, verify_password,
)

router = APIRouter(prefix="/auth", tags=["auth"])


class LoginIn(BaseModel):
    email: str
    password: str


class RefreshIn(BaseModel):
    refresh_token: str


class Tokens(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class AccessOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


@router.post("/login", response_model=Tokens)
def login(body: LoginIn, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == body.email.strip().lower()))
    if not user or not user.active or not verify_password(body.password, user.password_hash):
        raise ApiError(401, "invalid_credentials", "Email o contraseña incorrectos")
    return Tokens(
        access_token=create_access_token(user.id), refresh_token=create_refresh_token(user.id)
    )


@router.post("/refresh", response_model=AccessOut)
def refresh(body: RefreshIn, db: Session = Depends(get_db)):
    uid = decode_token(body.refresh_token, "refresh")
    user = db.get(User, uid) if uid else None
    if not user or not user.active:
        raise ApiError(401, "unauthorized", "Refresh token inválido")
    return AccessOut(access_token=create_access_token(user.id))


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(current_user)):
    return user
