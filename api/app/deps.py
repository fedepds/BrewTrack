from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.db import get_db
from app.errors import ApiError
from app.models import User
from app.security import decode_token

_bearer = HTTPBearer(auto_error=False)


def current_user(
    cred: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    uid = decode_token(cred.credentials, "access") if cred else None
    user = db.get(User, uid) if uid else None
    if user is None or not user.active:
        raise ApiError(401, "unauthorized", "Credenciales inválidas o ausentes")
    return user


def admin_only(user: User = Depends(current_user)) -> User:
    if user.role != "admin":
        raise ApiError(403, "forbidden", "Requiere rol admin")
    return user
