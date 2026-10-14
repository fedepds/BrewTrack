from fastapi import FastAPI
from prometheus_client import Counter, Histogram
from prometheus_fastapi_instrumentator import Instrumentator
from prometheus_fastapi_instrumentator.metrics import Info

# Etiquetas: plantilla de ruta, método y código exacto (RF-3). Sin IP ni usuario.
LABELS = ("handler", "method", "status")
REQUESTS = Counter("http_requests_total", "Pedidos HTTP.", LABELS)
LATENCY = Histogram(
    "http_request_duration_seconds", "Latencia de pedidos HTTP.", LABELS,
    buckets=(0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10),
)
EXCLUDED = ["^/metrics$", "^/api/v1/health$"]  # RF-5


def _observe(info: Info) -> None:
    # info.modified_handler vale "none" para rutas inexistentes (RF-4).
    labels = (info.modified_handler, info.method, info.modified_status)
    REQUESTS.labels(*labels).inc()
    LATENCY.labels(*labels).observe(info.modified_duration)


def _init_denied_series(app: FastAPI) -> None:
    # RF-11: Prometheus no ve el salto de "sin serie" a 1. Se crean en 0 las series 401 y 403
    # de cada ruta para que increase() cuente también la primera respuesta.
    # Se lee el esquema OpenAPI: lista las rutas de include_router (en FastAPI 0.143 no son
    # APIRoute en app.routes) con la misma plantilla que usa el instrumentator.
    for path, methods in app.openapi()["paths"].items():
        if path not in ("/metrics", "/api/v1/health"):
            for method in methods:
                for status in ("401", "403"):
                    REQUESTS.labels(path, method.upper(), status)


def install(app: FastAPI) -> None:
    inst = Instrumentator(
        should_group_status_codes=False, excluded_handlers=EXCLUDED
    ).add(_observe)
    inst.instrument(app)
    inst.expose(app, endpoint="/metrics", include_in_schema=False)
    _init_denied_series(app)
