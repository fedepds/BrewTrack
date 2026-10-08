import uuid
from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError

from app.config import settings

_ph = PasswordHasher()


def hash_password(password: str) -> str:
    return _ph.hash(password)


def verify_password(password: str, hashed: str) -> bool:
    try:
        return _ph.verify(hashed, password)
    except (VerifyMismatchError, InvalidHashError):
        return False


def _token(user_id: uuid.UUID, kind: str, ttl: timedelta) -> str:
    now = datetime.now(timezone.utc)
    claims = {"sub": str(user_id), "typ": kind, "iat": now, "exp": now + ttl}
    return jwt.encode(claims, settings.jwt_secret, algorithm="HS256")


def create_access_token(user_id: uuid.UUID) -> str:
    return _token(user_id, "access", timedelta(minutes=settings.access_ttl_min))


def create_refresh_token(user_id: uuid.UUID) -> str:
    return _token(user_id, "refresh", timedelta(days=settings.refresh_ttl_days))


def decode_token(token: str, kind: str) -> uuid.UUID | None:
    try:
        data = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
        if data.get("typ") != kind:
            return None
        return uuid.UUID(data["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        return None
