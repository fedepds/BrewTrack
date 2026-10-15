from app.security import create_access_token

ME = "/api/v1/auth/me"


def login(client, email="roaster@x.com", password="secret123"):
    return client.post("/api/v1/auth/login", json={"email": email, "password": password})


def test_login_ok(client, roaster):
    r = login(client)
    assert r.status_code == 200
    assert {"access_token", "refresh_token"} <= r.json().keys()


def test_login_email_is_case_insensitive(client, roaster):
    assert login(client, "ROASTER@X.COM").status_code == 200


def test_login_wrong_password(client, roaster):
    r = login(client, password="nope")
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "invalid_credentials"


def test_login_inactive_user(client, make_user):
    make_user("off@x.com", active=False)
    assert login(client, "off@x.com").status_code == 401


def test_me(client, roaster, auth):
    r = client.get(ME, headers=auth(roaster))
    assert r.status_code == 200
    assert r.json()["email"] == "roaster@x.com" and r.json()["role"] == "roaster"
    assert "password_hash" not in r.json()


def test_me_requires_token(client):
    r = client.get(ME)
    assert r.status_code == 401
    assert r.json()["error"]["code"] == "unauthorized"


def test_refresh_token_is_not_an_access_token(client, roaster):
    tokens = login(client).json()
    r = client.get(ME, headers={"Authorization": f"Bearer {tokens['refresh_token']}"})
    assert r.status_code == 401


def test_access_token_is_not_a_refresh_token(client, roaster):
    r = client.post("/api/v1/auth/refresh", json={"refresh_token": create_access_token(roaster.id)})
    assert r.status_code == 401


def test_refresh_returns_working_access_token(client, roaster):
    tokens = login(client).json()
    r = client.post("/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert r.status_code == 200
    r2 = client.get(ME, headers={"Authorization": f"Bearer {r.json()['access_token']}"})
    assert r2.status_code == 200


def test_token_of_deactivated_user_is_rejected(client, db, roaster, auth):
    headers = auth(roaster)
    roaster.active = False
    db.commit()
    assert client.get(ME, headers=headers).status_code == 401


def test_token_lifetimes(client, roaster):
    import jwt

    b = login(client).json()
    a = jwt.decode(b["access_token"], options={"verify_signature": False})
    r = jwt.decode(b["refresh_token"], options={"verify_signature": False})
    assert a["exp"] - a["iat"] == 3600
    assert r["exp"] - r["iat"] == 604800
