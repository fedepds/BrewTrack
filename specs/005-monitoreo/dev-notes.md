# 005 — Notas del developer

## Qué cambió
- `api/pyproject.toml`: `prometheus-fastapi-instrumentator>=7.0`.
- `api/app/metrics.py` (nuevo) y `api/app/main.py`: `/metrics` con contador e histograma; series 401/403 en 0 al arrancar (ver arreglo de QA).
- `api/tests/test_metrics.py` (nuevo): 7 pruebas.
- `monitoring/` (nuevo): `prometheus.yml` y provisioning de Grafana (fuente de datos, panel "BrewTrack API", 6 alertas).
- `compose.yaml`: `prometheus` y `grafana`, volúmenes `promdata` y `grafanadata`, `api:0.2.0`.
- `.env.example`: `GRAFANA_ADMIN_PASSWORD` vacía.
- `k8s/monitoring.yaml` (nuevo); `k8s/brewtrack.yaml`: `api:0.2.0`.
- `k8s/README.md`, `README.md`, `AGENTS.md`: monitoreo, contraseña de Grafana (RF-28) y línea de Grafana en "Comandos".

## Cómo probarlo
- Agregar `GRAFANA_ADMIN_PASSWORD` a `.env` y correr `podman compose up --build -d`. Grafana: http://127.0.0.1:3001.
- Manifiestos: `kubectl apply --dry-run=client -f k8s/`.
- Clúster: seguir "Monitoreo con Prometheus y Grafana" en `k8s/README.md`. La imagen `api:0.2.0` es nueva: hay que construirla y cargarla con `minikube image load`.

## Verificaciones (2026-10-13)
- `cd api && pytest`: 103 pasan.
- `cd web && flutter analyze`: sin problemas. `flutter test`: 15 pasan.
- `promtool check config monitoring/prometheus.yml`: SUCCESS.
- Compose: `api` sano, `/api/v1/health` 200 por `web`. Grafana carga la fuente de datos, el panel con 5 gráficos y las 6 alertas.
- `kubectl apply --dry-run=client -f k8s/`: código 0.

## Arreglo del hallazgo de QA (RF-11, CA-12), 2026-10-13
- Causa: `_init_denied_series` recorría `app.routes` buscando `APIRoute`. Con FastAPI 0.143.0 las rutas de `include_router` aparecen como `_IncludedRouter`, así que no se creó ninguna serie 401/403 en 0 y la alerta "Fuerza bruta" no veía el primer fallo tras reiniciar `api`.
- Arreglo en `api/app/metrics.py`: la función lee `app.openapi()["paths"]` y crea las series 401 y 403 de cada ruta y método, salvo `/metrics` y `/api/v1/health`. `install` corre al final de `main.py`, con todas las rutas ya registradas, así que el esquema en caché está completo; `/metrics` no entra (`include_in_schema=False`).
- Prueba: `test_first_denied_response_visible_as_increase` usa su propio `CollectorRegistry`. Ya no depende de otro test que cree la serie. Pasa sola y en la suite.
- Plantillas: se llamó a las 11 rutas del esquema sin token; todas las series 401 ya existían (34 series al arrancar). Solo aparecieron dos series 422 (login y refresh sin cuerpo), esperadas.
- Versiones: `.venv` local FastAPI 0.143.0 (python 3.14.8); imagen `brewtrack-api:0.2.0` FastAPI 0.143.0 (python 3.13). Misma versión.
- `cd api && pytest`: 103 pasan (con `brewtrack-test-db` iniciado). El test solo: 1 pasa.
- `cd web && flutter analyze`: sin problemas. `flutter test`: 15 pasan.
- `podman compose up --build -d api`: tras reiniciar y antes de cualquier pedido, `/metrics` dentro del contenedor trae `http_requests_total{handler="/api/v1/auth/login",method="POST",status="401"} 0.0` y su par `403`.
- Grafana y Minikube no se tocaron.

## Pendiente
- `.env` no tiene `GRAFANA_ADMIN_PASSWORD`. Las pruebas usaron un valor temporal pasado por el entorno del comando; después se borraron el contenedor `grafana` y su volumen para que el primer arranque real tome la contraseña de la persona.
- Pruebas en clúster hechas el 2026-10-14 en el namespace de la persona (PA-2).

## Arreglo en Minikube, 2026-10-14
- `k8s/brewtrack.yaml`: la línea 1 empezaba con `~#`. `kubectl apply` rechazaba el PVC; el dry-run de cliente no lo veía. Se cambió a `#`. Detalle de las pruebas en clúster en `qa-report.md`.

## Preguntas abiertas
Ninguna.
