URL = "/api/v1/users"


def _new(**kw):
    return {"email": "new@x.com", "name": "New", "password": "longenough1", "role": "roaster", **kw}


def test_only_admin_can_list(client, roaster, admin, auth):
    assert client.get(URL).status_code == 401
    assert client.get(URL, headers=auth(roaster)).status_code == 403
    r = client.get(URL, headers=auth(admin))
    assert r.status_code == 200 and len(r.json()) == 2


def test_create_user_and_login(client, admin, auth):
    r = client.post(URL, json=_new(email="New@X.com"), headers=auth(admin))
    assert r.status_code == 201 and r.json()["email"] == "new@x.com" and r.json()["active"] is True
    login = client.post("/api/v1/auth/login", json={"email": "new@x.com", "password": "longenough1"})
    assert login.status_code == 200


def test_create_duplicate_email_is_409(client, admin, auth):
    client.post(URL, json=_new(), headers=auth(admin))
    r = client.post(URL, json=_new(), headers=auth(admin))
    assert r.status_code == 409 and r.json()["error"]["code"] == "duplicate_email"


def test_create_validates_input(client, admin, auth):
    assert client.post(URL, json=_new(password="short"), headers=auth(admin)).status_code == 422
    assert client.post(URL, json=_new(role="boss"), headers=auth(admin)).status_code == 422
    assert client.post(URL, json=_new(email="not-an-email"), headers=auth(admin)).status_code == 422


def test_patch_user(client, admin, roaster, auth):
    r = client.patch(
        f"{URL}/{roaster.id}", json={"name": "Renamed", "password": "anotherpass1"}, headers=auth(admin)
    )
    assert r.status_code == 200 and r.json()["name"] == "Renamed"
    login = client.post("/api/v1/auth/login", json={"email": "roaster@x.com", "password": "anotherpass1"})
    assert login.status_code == 200


def test_patch_null_is_rejected(client, admin, roaster, auth):
    assert client.patch(f"{URL}/{roaster.id}", json={"name": None}, headers=auth(admin)).status_code == 422


def test_cannot_deactivate_or_demote_last_admin(client, admin, make_user, auth):
    url = f"{URL}/{admin.id}"
    r = client.patch(url, json={"active": False}, headers=auth(admin))
    assert r.status_code == 409 and r.json()["error"]["code"] == "last_admin"
    assert client.patch(url, json={"role": "roaster"}, headers=auth(admin)).status_code == 409
    make_user("admin2@x.com", "admin")
    assert client.patch(url, json={"active": False}, headers=auth(admin)).status_code == 200
