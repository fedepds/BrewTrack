from prometheus_client.parser import text_string_to_metric_families

ROASTS = "/api/v1/roasts"


def _metrics(client) -> dict[str, float]:
    r = client.get("/metrics")
    assert r.status_code == 200
    out = {}
    for fam in text_string_to_metric_families(r.text):
        for s in fam.samples:
            labels = ",".join(f"{k}={v}" for k, v in sorted(s.labels.items()))
            out[f"{s.name}{{{labels}}}" if labels else s.name] = s.value
    return out


def _roast(lot, **kw):
    return {
        "lot_id": str(lot.id), "roasted_at": "2026-02-01T10:00:00Z", "green_in_kg": 10,
        "roasted_out_kg": 8.5, "duration_s": 600, "drop_temp_c": 205.0, "roast_level": "dark", **kw,
    }


def test_green_stock_is_computed_on_each_scrape(client, make_lot, make_roast, roaster):
    lot = make_lot("GL-1", kg="60")
    make_lot("GL-2", kg="5")
    make_roast(lot, roaster, green_in="10", out="8.5")
    m = _metrics(client)
    assert m["brewtrack_green_stock_kg"] == 55.0
    assert m["brewtrack_green_lots_with_stock"] == 2


def test_lot_without_stock_is_not_counted(client, make_lot, make_roast, roaster):
    lot = make_lot("GL-1", kg="10")
    make_roast(lot, roaster, green_in="10", out="8")
    m = _metrics(client)
    assert m["brewtrack_green_stock_kg"] == 0.0
    assert m["brewtrack_green_lots_with_stock"] == 0


def test_created_roast_increments_counters(client, make_lot, roaster, auth):
    lot = make_lot(kg="60")
    before = _metrics(client)
    r = client.post(ROASTS, json=_roast(lot), headers=auth(roaster))
    assert r.status_code == 201
    after = _metrics(client)
    key = "brewtrack_roasts_created_total{roast_level=dark}"
    assert after[key] - before.get(key, 0) == 1
    assert after["brewtrack_roast_green_in_kg_total"] - before["brewtrack_roast_green_in_kg_total"] == 10
    assert after["brewtrack_roast_out_kg_total"] - before["brewtrack_roast_out_kg_total"] == 8.5


def test_rejected_roast_does_not_count(client, make_lot, roaster, auth):
    lot = make_lot(kg="5")
    before = _metrics(client)
    r = client.post(ROASTS, json=_roast(lot), headers=auth(roaster))
    assert r.status_code == 409
    after = _metrics(client)
    assert after["brewtrack_roast_green_in_kg_total"] == before["brewtrack_roast_green_in_kg_total"]
