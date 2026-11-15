import uuid

R = "/api/v1/roasts"


def _w(**kw):
    return {"withdrawn_at": "2026-02-10T10:00:00Z", "kg": 2, "reason": "sale", **kw}


def _post(client, roast, user, auth, **kw):
    return client.post(f"{R}/{roast.id}/withdrawals", json=_w(**kw), headers=auth(user))


def _stock(client, roast, user, auth):
    return client.get(f"{R}/{roast.id}", headers=auth(user)).json()["roasted_stock_kg"]


def test_roaster_creates_withdrawal_and_stock_drops(client, roaster, auth, make_lot, make_roast):
    roast = make_roast(make_lot(), roaster)
    r = _post(client, roast, roaster, auth)
    assert r.status_code == 201
    assert r.json()["user_name"] == "roaster" and r.json()["kg"] == 2.0
    d = client.get(f"{R}/{roast.id}", headers=auth(roaster)).json()
    assert d["roasted_stock_kg"] == 6.5 and len(d["withdrawals"]) == 1


def test_withdrawal_cannot_exceed_roasted_stock(client, roaster, auth, make_lot, make_roast):
    roast = make_roast(make_lot(), roaster)
    r = _post(client, roast, roaster, auth, kg=9)
    assert r.status_code == 409 and r.json()["error"]["code"] == "insufficient_roasted_stock"
    assert "8.5" in r.json()["error"]["message"]


def test_withdrawal_may_take_exact_stock(client, roaster, auth, make_lot, make_roast):
    roast = make_roast(make_lot(), roaster)
    assert _post(client, roast, roaster, auth, kg=8.5).status_code == 201
    assert _stock(client, roast, roaster, auth) == 0.0
    assert _post(client, roast, roaster, auth, kg=0.001).status_code == 409


def test_withdrawal_validation(client, roaster, auth, make_lot, make_roast):
    roast = make_roast(make_lot(), roaster)
    for bad in ({"kg": 0}, {"kg": 0.0001}, {"reason": "gift"}):
        assert _post(client, roast, roaster, auth, **bad).status_code == 422


def test_withdrawal_unknown_roast_is_404(client, roaster, auth):
    r = client.post(f"{R}/{uuid.uuid4()}/withdrawals", json=_w(), headers=auth(roaster))
    assert r.status_code == 404 and r.json()["error"]["code"] == "not_found"


def test_delete_withdrawal_is_admin_only(client, roaster, admin, auth, make_lot, make_roast):
    roast = make_roast(make_lot(), roaster)
    wid = _post(client, roast, roaster, auth).json()["id"]
    url = f"{R}/{roast.id}/withdrawals/{wid}"
    assert client.delete(url, headers=auth(roaster)).status_code == 403
    assert client.delete(url, headers=auth(admin)).status_code == 204
    assert _stock(client, roast, roaster, auth) == 8.5


def test_delete_withdrawal_of_other_roast_is_404(client, roaster, admin, auth, make_lot, make_roast):
    lot = make_lot()
    a, b = make_roast(lot, roaster), make_roast(lot, roaster)
    wid = _post(client, a, roaster, auth).json()["id"]
    r = client.delete(f"{R}/{b.id}/withdrawals/{wid}", headers=auth(admin))
    assert r.status_code == 404 and r.json()["error"]["code"] == "not_found"


def test_list_withdrawals_newest_first(client, roaster, auth, make_lot, make_roast):
    roast = make_roast(make_lot(), roaster)
    _post(client, roast, roaster, auth, withdrawn_at="2026-02-10T10:00:00Z", kg=1)
    _post(client, roast, roaster, auth, withdrawn_at="2026-02-12T10:00:00Z", kg=2)
    r = client.get(f"{R}/{roast.id}/withdrawals", headers=auth(roaster))
    assert [w["kg"] for w in r.json()] == [2.0, 1.0]


def test_roast_with_withdrawals_cannot_be_deleted(client, roaster, admin, auth, make_lot, make_roast):
    roast = make_roast(make_lot(), roaster)
    _post(client, roast, roaster, auth)
    r = client.delete(f"{R}/{roast.id}", headers=auth(admin))
    assert r.status_code == 409 and r.json()["error"]["code"] == "roast_has_withdrawals"


def test_patch_roast_out_below_withdrawn_is_409(client, roaster, auth, make_lot, make_roast):
    roast = make_roast(make_lot(), roaster)
    _post(client, roast, roaster, auth, kg=5)
    url = f"{R}/{roast.id}"
    r = client.patch(url, json={"roasted_out_kg": 4}, headers=auth(roaster))
    assert r.status_code == 409 and r.json()["error"]["code"] == "insufficient_roasted_stock"
    ok = client.patch(url, json={"roasted_out_kg": 5}, headers=auth(roaster))
    assert ok.status_code == 200 and ok.json()["roasted_stock_kg"] == 0.0


def test_withdrawals_require_auth(client, roaster, make_lot, make_roast):
    roast = make_roast(make_lot(), roaster)
    assert client.get(f"{R}/{roast.id}/withdrawals").status_code == 401
