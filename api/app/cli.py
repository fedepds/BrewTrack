import argparse
import getpass
import sys

from sqlalchemy import select

from app.db import SessionLocal
from app.models import User
from app.security import hash_password
from app.seed import run_seed


def create_admin(email: str, name: str, password: str) -> User:
    if len(password) < 8:
        raise ValueError("La contraseña debe tener al menos 8 caracteres")
    with SessionLocal() as db:
        if db.scalar(select(User).where(User.email == email.lower())):
            raise ValueError("Ya existe un usuario con ese email")
        user = User(
            email=email.lower(), name=name, role="admin", password_hash=hash_password(password)
        )
        db.add(user)
        db.commit()
    # Con el admin ya guardado, cualquier fallo de la carga no lo deshace.
    for line in run_seed(lots=False):
        print(line)
    return user


def main() -> None:
    p = argparse.ArgumentParser(prog="python -m app.cli")
    p.add_argument("command", choices=["create-admin"])
    p.add_argument("--email", required=True)
    p.add_argument("--name", default="Admin")
    a = p.parse_args()
    try:
        create_admin(a.email, a.name, getpass.getpass("Contraseña: "))
    except ValueError as e:
        sys.exit(str(e))
    print("Admin creado")


if __name__ == "__main__":
    main()
