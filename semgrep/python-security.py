# Casos de prueba de semgrep/python-security.yaml: semgrep --test semgrep/
# "ruleid" marca la línea siguiente como hallazgo esperado; "ok" como línea que no debe marcar.
import hashlib
import logging

import jwt
import sqlalchemy
from sqlalchemy import text

log = logging.getLogger(__name__)


def jwt_cases(token, key):
    # ruleid: brewtrack-jwt-decode-sin-verificar
    jwt.decode(token, key)
    # ruleid: brewtrack-jwt-decode-sin-verificar
    jwt.decode(token, key, algorithms=["HS256"], options={"verify_signature": False})
    # ruleid: brewtrack-jwt-decode-sin-verificar
    jwt.decode(token, key, algorithms=["HS256", "none"])
    # ok: brewtrack-jwt-decode-sin-verificar
    jwt.decode(token, key, algorithms=["HS256"])


def sql_cases(db, name):
    # ruleid: brewtrack-sql-armado-con-texto
    db.execute(text(f"SELECT * FROM users WHERE email = '{name}'"))
    # ruleid: brewtrack-sql-armado-con-texto
    db.execute(sqlalchemy.text("SELECT * FROM users WHERE email = '%s'" % name))
    # ruleid: brewtrack-sql-armado-con-texto
    db.execute("SELECT * FROM users WHERE email = '" + name)
    # ok: brewtrack-sql-armado-con-texto
    db.execute(text("SELECT * FROM users WHERE email = :e"), {"e": name})
    # ok: brewtrack-sql-armado-con-texto
    db.execute(text("TRUNCATE roasts, green_lots, users CASCADE"))


def like_cases(Lot, country):
    # ruleid: brewtrack-like-sin-escape
    Lot.origin_country.ilike(f"%{country}%")
    # ruleid: brewtrack-like-sin-escape
    Lot.origin_country.like("%" + country + "%")
    # ok: brewtrack-like-sin-escape
    Lot.origin_country.icontains(country, autoescape=True)


def hash_cases(data):
    # ruleid: brewtrack-hash-debil-para-claves
    hashlib.md5(data)
    # ruleid: brewtrack-hash-debil-para-claves
    hashlib.new("sha1", data)
    # ok: brewtrack-hash-debil-para-claves
    hashlib.sha256(data)


def log_cases(settings, user, password, token):
    # ruleid: brewtrack-secreto-en-log
    log.info("clave %s", settings.jwt_secret)
    # ruleid: brewtrack-secreto-en-log
    print(f"admin con clave {password}")
    # ruleid: brewtrack-secreto-en-log
    log.debug("token=%s", token)
    # ok: brewtrack-secreto-en-log
    log.info("Se creó el admin %s", user.email)
