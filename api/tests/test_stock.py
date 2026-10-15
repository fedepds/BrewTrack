# Stock en cada lectura y tras cada escritura (spec 006). Solo usa la API.
LOTS = "/api/v1/green-lots"
ROASTS = "/api/v1/roasts"


def _lot_body(code="GL-1", kg=100):
    return {
        "code": code, "origin_country": "Colombia", "variety": "Caturra", "process": "washed",
        "harvest_year": 2026, "received_at": "2026-01-01", "received_kg": kg,
    }


def _roast_body(lot_id, kg=30):
    return {
        "lot_id": lot_id, "roasted_at": "2026-02-01T10:00:00Z", "green_in_kg": kg,
        "roasted_out_kg": kg - 1, "duration_s": 600, "drop_temp_c": 205.0, "roast_level": "medium",
    }


def _stocks(client, h, lot_id, roast_id=None):
    """Stock del lote en detalle, listado y (si hay) detalle del tueste."""
    detail = client.get(f"{LOTS}/{lot_id}", headers=h).json()["stock_kg"]
    listed = next(i for i in client.get(LOTS, headers=h).json()["items"] if i["id"] == lot_id)["stock_kg"]
    out = [detail, listed]
    if roast_id:
        out.append(client.get(f"{ROASTS}/{roast_id}", headers=h).json()["lot"]["stock_kg"])
    return out


def _setup(client, roaster, auth, kg=30):
    h = auth(roaster)
    lot_id = client.post(LOTS, json=_lot_body(), headers=h).json()["id"]
    roast = client.post(ROASTS, json=_roast_body(lot_id, kg), headers=h).json()
    return h, lot_id, roast["id"]


def test_new_lot_has_full_stock(client, roaster, auth):
    h = auth(roaster)
    r = client.post(LOTS, json=_lot_body(), headers=h)
    assert r.status_code == 201 and r.json()["stock_kg"] == 100
    assert _stocks(client, h, r.json()["id"]) == [100, 100]


def test_stock_after_create_edit_delete_roast(client, roaster, admin, auth):
    h, lot_id, roast_id = _setup(client, roaster, auth)
    assert _stocks(client, h, lot_id, roast_id) == [70, 70, 70]
    r = client.patch(f"{ROASTS}/{roast_id}", json={"green_in_kg": 40}, headers=h)
    assert r.status_code == 200
    assert _stocks(client, h, lot_id, roast_id) == [60, 60, 60]
    assert client.delete(f"{ROASTS}/{roast_id}", headers=auth(admin)).status_code == 204
    assert _stocks(client, h, lot_id) == [100, 100]


def test_patch_lot_returns_current_stock(client, roaster, auth):
    h, lot_id, _ = _setup(client, roaster, auth)
    r = client.patch(f"{LOTS}/{lot_id}", json={"received_kg": 120}, headers=h)
    assert r.status_code == 200 and r.json()["stock_kg"] == 90
    assert _stocks(client, h, lot_id) == [90, 90]


def test_patch_lot_without_received_kg_returns_current_stock(client, roaster, auth):
    h, lot_id, _ = _setup(client, roaster, auth)
    r = client.patch(f"{LOTS}/{lot_id}", json={"notes": "x"}, headers=h)
    assert r.status_code == 200 and r.json()["stock_kg"] == 70


def test_summary_matches_lot_list(client, roaster, auth):
    h, _, _ = _setup(client, roaster, auth)
    second = client.post(LOTS, json=_lot_body("GL-2", 50), headers=h).json()["id"]
    client.post(ROASTS, json=_roast_body(second, 50), headers=h)  # lote 2 agotado
    items = client.get(LOTS, headers=h).json()["items"]
    s = client.get("/api/v1/stats/summary", headers=h).json()
    assert float(s["stock_kg"]) == sum(i["stock_kg"] for i in items) == 70
    assert s["lots_in_stock"] == sum(1 for i in items if i["stock_kg"] > 0) == 1


def test_roast_over_stock_is_rejected_and_stock_unchanged(client, roaster, auth):
    h, lot_id, roast_id = _setup(client, roaster, auth)
    r = client.post(ROASTS, json=_roast_body(lot_id, 71), headers=h)
    assert r.status_code == 409
    assert r.json() == {"error": {"code": "insufficient_stock", "message": "Stock disponible: 70.000 kg"}}
    r = client.patch(f"{ROASTS}/{roast_id}", json={"green_in_kg": 101}, headers=h)
    assert r.status_code == 409 and r.json()["error"]["code"] == "insufficient_stock"
    assert r.json()["error"]["message"] == "Stock disponible: 100.000 kg"
    assert _stocks(client, h, lot_id, roast_id) == [70, 70, 70]
