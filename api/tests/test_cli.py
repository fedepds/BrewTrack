import pytest

from app.cli import create_admin


def test_create_admin():
    u = create_admin("Boss@X.com", "Boss", "longenough1")
    assert u.role == "admin" and u.email == "boss@x.com" and u.password_hash != "longenough1"


def test_create_admin_rejects_short_password():
    with pytest.raises(ValueError):
        create_admin("a@x.com", "A", "short")


def test_create_admin_rejects_duplicate_email():
    create_admin("a@x.com", "A", "longenough1")
    with pytest.raises(ValueError):
        create_admin("A@x.com", "A2", "longenough1")
