import os
import subprocess
import sys
from pathlib import Path

from app.config import TEMPLATE_JWT_SECRET

API_DIR = Path(__file__).parent.parent


def _boot(secret: str) -> subprocess.CompletedProcess:
    env = {**os.environ, "JWT_SECRET": secret}
    return subprocess.run(
        [sys.executable, "-c", "import app.main"], cwd=API_DIR, env=env, capture_output=True, text=True
    )


def _assert_no_leak(secret: str, out: str) -> None:
    # Ningún fragmento de 8 caracteres o más del secreto aparece en la salida.
    assert not any(secret[i:i + 8] in out for i in range(len(secret) - 7))


def test_short_secret_is_rejected():
    secret = "Zq7#k2" * 5 + "x"  # 31 caracteres
    assert len(secret) == 31
    r = _boot(secret)
    out = r.stdout + r.stderr
    assert r.returncode != 0
    assert "JWT_SECRET" in out and "32" in out
    _assert_no_leak(secret, out)


def test_template_secret_is_rejected():
    r = _boot(TEMPLATE_JWT_SECRET)
    out = r.stdout + r.stderr
    assert r.returncode != 0
    assert "JWT_SECRET" in out and "plantilla" in out
    _assert_no_leak(TEMPLATE_JWT_SECRET, out)


def test_valid_secret_boots():
    r = _boot("Zq7#k2mP" * 4)  # 32 caracteres
    assert r.returncode == 0, r.stderr


def test_valid_secret_logs_in(client, make_user):
    make_user("a@x.com", password="secret123")
    r = client.post("/api/v1/auth/login", json={"email": "a@x.com", "password": "secret123"})
    assert r.status_code == 200 and "access_token" in r.json()
