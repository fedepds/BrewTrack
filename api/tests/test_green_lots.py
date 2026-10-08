import uuid

URL = "/api/v1/green-lots"


def _body(**kw):
    return {
        "code": "GL-2026-001", "origin_country": "Colombia", "variety": "Caturra",
        "process": "washed", "harvest_year": 2026, "received_at": "2026-01-15",
        "received_kg": 69, **kw,
    }


def test_requires_auth(client):
    assert client.get(URL).status_code == 401


def test_create_lot(client, roaster, auth):
    r = client.post(URL, json=_body(), headers=auth(roaster))
    assert r.status_code == 201
    assert r.json()["stock_kg"] == 69.0 and r.json()["received_kg"] == 69.0


def test_duplicate_code_is_409(client, roaster, auth):
    client.post(URL, json=_body(), headers=auth(roaster))
    r = client.post(URL, json=_body(), headers=auth(roaster))
    assert r.status_code == 409 and r.json()["error"]["code"] == "duplicate_code"


def test_validation(client, roaster, auth):
    r = client.post(URL, json=_body(received_kg=0), headers=auth(roaster))
    assert r.status_code == 422 and r.json()["error"]["code"] == "validation_error"


def test_detail_has_stock_and_roasts(client, roaster, auth, make_lot, make_roast):
    lot = make_lot(kg="60")
    make_roast(lot, roaster, green_in="10", out="8.5")
    d = client.get(f"{URL}/{lot.id}", headers=auth(roaster)).json()
    assert d["stock_kg"] == 50.0
    assert len(d["roasts"]) == 1 and d["roasts"][0]["lot_code"] == "GL-1"
    assert d["roasts"][0]["roaster_name"] == "roaster"


def test_unknown_lot_is_404(client, roaster, auth):
    r = client.get(f"{URL}/{uuid.uuid4()}", headers=auth(roaster))
    assert r.status_code == 404 and r.json()["error"]["code"] == "not_found"


def test_list_filters_and_pagination(client, roaster, auth, make_lot):
    make_lot("GL-1")
    make_lot("GL-2", origin_country="Kenya", process="natural")
    make_lot("GL-3")
    h = auth(roaster)
    assert client.get(f"{URL}?country=colom", headers=h).json()["total"] == 2
    assert client.get(f"{URL}?process=NAT", headers=h).json()["total"] == 1
    page = client.get(f"{URL}?limit=1&offset=1", headers=h).json()
    assert len(page["items"]) == 1 and page["total"] == 3 and page["limit"] == 1


def test_patch_lot(client, roaster, auth, make_lot):
    lot = make_lot()
    r = client.patch(f"{URL}/{lot.id}", json={"notes": "dulce", "region": None}, headers=auth(roaster))
    assert r.status_code == 200 and r.json()["notes"] == "dulce"
    assert client.patch(f"{URL}/{lot.id}", json={"code": None}, headers=auth(roaster)).status_code == 422


def test_cannot_lower_received_kg_below_roasted(client, roaster, auth, make_lot, make_roast):
    lot = make_lot(kg="60")
    make_roast(lot, roaster, green_in="10", out="8.5")
    url = f"{URL}/{lot.id}"
    r = client.patch(url, json={"received_kg": 9.999}, headers=auth(roaster))
    assert r.status_code == 409 and r.json()["error"]["code"] == "insufficient_stock"
    r = client.patch(url, json={"received_kg": 10}, headers=auth(roaster))
    assert r.status_code == 200 and r.json()["stock_kg"] == 0.0


def test_delete_rules(client, roaster, admin, auth, make_lot, make_roast):
    with_roasts, empty = make_lot("GL-1"), make_lot("GL-2")
    make_roast(with_roasts, roaster)
    assert client.delete(f"{URL}/{empty.id}", headers=auth(roaster)).status_code == 403
    r = client.delete(f"{URL}/{with_roasts.id}", headers=auth(admin))
    assert r.status_code == 409 and r.json()["error"]["code"] == "lot_has_roasts"
    assert client.delete(f"{URL}/{empty.id}", headers=auth(admin)).status_code == 204
    assert client.get(f"{URL}/{empty.id}", headers=auth(admin)).status_code == 404
