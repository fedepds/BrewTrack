import uuid

URL = "/api/v1/roasts"
LOTS = "/api/v1/green-lots"


def _body(lot, **kw):
    return {
        "lot_id": str(lot.id), "roasted_at": "2026-02-01T10:00:00Z", "green_in_kg": 10,
        "roasted_out_kg": 8.5, "duration_s": 600, "drop_temp_c": 205.0, "roast_level": "medium", **kw,
    }


def test_create_roast_computes_loss_and_reduces_stock(client, roaster, auth, make_lot):
    lot = make_lot(kg="60")
    r = client.post(URL, json=_body(lot), headers=auth(roaster))
    assert r.status_code == 201
    b = r.json()
    assert b["loss_pct"] == 15.0 and b["lot_code"] == "GL-1"
    assert b["roaster_name"] == "roaster" and b["roaster_id"] == str(roaster.id)
    assert client.get(f"{LOTS}/{lot.id}", headers=auth(roaster)).json()["stock_kg"] == 50.0


def test_requires_auth(client):
    assert client.get(URL).status_code == 401


def test_roast_cannot_exceed_stock(client, roaster, auth, make_lot):
    lot = make_lot(kg="5")
    r = client.post(URL, json=_body(lot), headers=auth(roaster))
    assert r.status_code == 409 and r.json()["error"]["code"] == "insufficient_stock"


def test_roast_may_consume_exactly_the_remaining_stock(client, roaster, auth, make_lot):
    lot = make_lot(kg="10")
    ok = client.post(URL, json=_body(lot, roasted_out_kg=9), headers=auth(roaster))
    assert ok.status_code == 201
    assert client.get(f"{LOTS}/{lot.id}", headers=auth(roaster)).json()["stock_kg"] == 0.0
    over = client.post(URL, json=_body(lot, green_in_kg=0.001, roasted_out_kg=0.001), headers=auth(roaster))
    assert over.status_code == 409


def test_out_cannot_exceed_in(client, roaster, auth, make_lot):
    r = client.post(URL, json=_body(make_lot(), roasted_out_kg=11), headers=auth(roaster))
    assert r.status_code == 422 and r.json()["error"]["code"] == "validation_error"


def test_invalid_level_is_422(client, roaster, auth, make_lot):
    r = client.post(URL, json=_body(make_lot(), roast_level="burnt"), headers=auth(roaster))
    assert r.status_code == 422


def test_unknown_lot_is_404(client, roaster, auth, make_lot):
    lot = make_lot()
    r = client.post(URL, json=_body(lot, lot_id=str(uuid.uuid4())), headers=auth(roaster))
    assert r.status_code == 404 and r.json()["error"]["code"] == "lot_not_found"


def test_detail_includes_origin_lot(client, roaster, auth, make_lot, make_roast):
    lot = make_lot()
    roast = make_roast(lot, roaster)
    d = client.get(f"{URL}/{roast.id}", headers=auth(roaster)).json()
    assert d["lot"]["code"] == "GL-1" and d["lot"]["origin_country"] == "Colombia"
    assert d["lot"]["stock_kg"] == 50.0


def test_patch_permissions_and_rules(client, roaster, admin, make_user, auth, make_lot, make_roast):
    lot = make_lot(kg="20")
    roast = make_roast(lot, roaster, green_in="10", out="8.5")
    other = make_user("other@x.com", "roaster")
    url = f"{URL}/{roast.id}"
    assert client.patch(url, json={"notes": "x"}, headers=auth(other)).status_code == 403
    r = client.patch(url, json={"roasted_out_kg": 8}, headers=auth(roaster))
    assert r.status_code == 200 and r.json()["loss_pct"] == 20.0
    # el stock exacto del lote (20) es válido porque se excluye el propio tueste
    assert client.patch(url, json={"green_in_kg": 20}, headers=auth(admin)).status_code == 200
    assert client.patch(url, json={"green_in_kg": 20.001}, headers=auth(admin)).status_code == 409
    assert client.patch(url, json={"roasted_out_kg": 30}, headers=auth(admin)).status_code == 422


def test_delete_is_admin_only_and_restores_stock(client, roaster, admin, auth, make_lot, make_roast):
    lot = make_lot(kg="60")
    roast = make_roast(lot, roaster, green_in="10")
    assert client.delete(f"{URL}/{roast.id}", headers=auth(roaster)).status_code == 403
    assert client.delete(f"{URL}/{roast.id}", headers=auth(admin)).status_code == 204
    assert client.get(f"{LOTS}/{lot.id}", headers=auth(admin)).json()["stock_kg"] == 60.0


def test_list_filters(client, roaster, auth, make_lot, make_roast):
    a, b = make_lot("GL-1"), make_lot("GL-2")
    make_roast(a, roaster, roast_level="light")
    make_roast(b, roaster, roast_level="dark")
    h = auth(roaster)
    assert client.get(f"{URL}?level=dark", headers=h).json()["total"] == 1
    assert client.get(f"{URL}?lot_id={a.id}", headers=h).json()["items"][0]["lot_code"] == "GL-1"
    assert client.get(f"{URL}?date_from=2026-02-01&date_to=2026-02-01", headers=h).json()["total"] == 2
    assert client.get(f"{URL}?date_from=2026-02-02", headers=h).json()["total"] == 0
    assert client.get(f"{URL}?limit=1", headers=h).json()["total"] == 2
