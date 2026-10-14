from uuid import uuid4

from app.main import app

LOGIN = "/api/v1/auth/login"


def _metrics(client) -> str:
    r = client.get("/metrics")
    assert r.status_code == 200
    return r.text


def test_metrics_text_format(client):
    r = client.get("/metrics")
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("text/plain")
    assert "# TYPE http_requests_total counter" in r.text


def test_failed_login_counted(client):
    client.post(LOGIN, json={"email": "no@x.com", "password": "bad"})
    line = next(
        l for l in _metrics(client).splitlines()
        if l.startswith("http_requests_total{") and f'handler="{LOGIN}"' in l and 'status="401"' in l
    )
    assert 'method="POST"' in line and float(line.rsplit(" ", 1)[1]) >= 1


def test_health_and_metrics_not_counted(client):
    for _ in range(3):
        client.get("/api/v1/health")
    for l in _metrics(client).splitlines():
        if l.startswith(("http_requests_total", "http_request_duration_seconds")):
            assert 'handler="/api/v1/health"' not in l and 'handler="/metrics"' not in l


def test_route_template_without_uuid(client, admin, auth):
    lot_id = str(uuid4())
    client.get(f"/api/v1/green-lots/{lot_id}", headers=auth(admin))
    body = _metrics(client)
    assert 'handler="/api/v1/green-lots/{lot_id}"' in body
    assert lot_id not in body


def test_unknown_urls_not_in_metrics(client):
    client.get("/inventada-uno-xyz")
    client.get("/api/v1/inventada-dos-xyz")
    body = _metrics(client)
    assert "inventada" not in body
    assert 'handler="none"' in body


def test_first_denied_response_visible_as_increase(monkeypatch):
    # RF-11: la serie 401 y 403 de login existe en 0 desde el arranque, antes de cualquier pedido.
    # Registro limpio: no depende de lo que otros tests hayan contado.
    from prometheus_client import CollectorRegistry, Counter
    from app import metrics

    reg = CollectorRegistry()
    monkeypatch.setattr(metrics, "REQUESTS", Counter("http_requests_total", "x", metrics.LABELS, registry=reg))
    metrics._init_denied_series(app)
    for status in ("401", "403"):
        assert reg.get_sample_value(
            "http_requests_total", {"handler": LOGIN, "method": "POST", "status": status}
        ) == 0
    assert reg.get_sample_value(
        "http_requests_total", {"handler": "/api/v1/health", "method": "GET", "status": "401"}
    ) is None


def test_metrics_not_in_openapi(client):
    assert "/metrics" not in client.get("/api/v1/openapi.json").json()["paths"]
