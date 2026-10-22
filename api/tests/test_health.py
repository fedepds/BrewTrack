def test_health(client):
    r = client.get("/api/v1/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_unknown_route_uses_error_envelope(client):
    r = client.get("/api/v1/nope")
    assert r.status_code == 404
    assert r.json()["error"]["code"] == "http_error"


def test_metrics(client):
    client.get("/api/v1/health")
    r = client.get("/metrics")
    assert r.status_code == 200
    assert "http_requests_total" in r.text
