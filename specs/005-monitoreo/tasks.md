# 005 — Tareas

- [x] T1. Dependencia `prometheus-fastapi-instrumentator` y `api/app/metrics.py`; `install(app)` en `main.py` (RF-1 a RF-5, RF-11).
- [x] T2. `api/tests/test_metrics.py` (CA-1 a CA-6).
- [x] T3. `monitoring/prometheus.yml` (RF-7, CA-7).
- [x] T4. Provisioning de Grafana: fuente de datos, panel y reglas (RF-8 a RF-13, CA-11).
- [x] T5. `compose.yaml`: `prometheus`, `grafana`, volúmenes, `api:0.2.0`; `.env.example` (RF-15 a RF-20, CA-9, CA-17, CA-18).
- [x] T6. `k8s/monitoring.yaml` y `api:0.2.0` en `k8s/brewtrack.yaml` (RF-20 a RF-24b, CA-19, CA-20).
- [x] T7. `k8s/README.md`, `README.md` y línea en `AGENTS.md` (RF-26 a RF-28, CA-27, CA-28).
- [x] T8. Verificar: pytest, flutter, `promtool`, compose, `kubectl apply --dry-run=client` (CA-29).
