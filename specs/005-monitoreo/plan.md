# 005 — Plan

## Constitución

| Regla | Cómo la cumple este cambio |
|---|---|
| Alcance | Mide solo tráfico HTTP de la API. La constitución ya suma el monitoreo (commit c26c758). Sin métricas de negocio. |
| Stock | No toca cálculos. |
| Permisos | Ningún endpoint de `/api/v1` cambia. `/metrics` queda fuera de `/api/v1` y nginx no lo publica. Grafana exige login. |
| Errores | Sin endpoints nuevos en `/api/v1`. `/metrics` responde texto de Prometheus. |
| Esquema | Sin cambios ni migraciones. |
| Secretos | `GRAFANA_ADMIN_PASSWORD` entra por `.env` en compose y por `secretKeyRef` a `brewtrack-secrets` en Minikube. Ningún archivo versionado trae su valor. |

## Diseño

- **RF-1 a RF-5.** `api/app/metrics.py` arma un `Instrumentator` con `should_group_status_codes=False`, excluye `/metrics` y `/api/v1/health` y registra métricas propias: `http_requests_total` (contador) y `http_request_duration_seconds` (histograma), con etiquetas `handler`, `method` y `status`. `handler` es la plantilla de la ruta; una ruta inexistente vale `none`. `install(app)` se llama al final de `main.py`, con las rutas ya registradas.
- **RF-11.** `install` crea en 0 las series `401` y `403` de cada ruta. Así `increase()` cuenta también la primera respuesta denegada.
- **RF-6.** nginx no cambia: solo hace proxy de `/api/`.
- **RF-7 a RF-14.** `monitoring/prometheus.yml` (scrape de `api:8000` cada 15 s) y `monitoring/grafana/provisioning/` con `datasources/`, `dashboards/` (proveedor y `brewtrack-api.json`, 5 gráficos) y `alerting/rules.yaml` (6 reglas, evaluadas cada 1 min). Las reglas usan `or vector(0)` donde hace falta y `noDataState: OK`, así que sin tráfico no se dispara nada (RF-12). El nombre `api` resuelve en compose y en Minikube, así que un solo archivo sirve para los dos.
- **RF-15 a RF-19.** `compose.yaml` suma `prometheus` (`prom/prometheus:v3.5.0`, sin puerto) y `grafana` (`grafana/grafana:12.2.0`, `127.0.0.1:3001`), con los volúmenes `promdata` y `grafanadata`. El `entrypoint` de `grafana` falla con "Falta GRAFANA_ADMIN_PASSWORD en .env" si la variable está vacía. `GF_AUTH_ANONYMOUS_ENABLED=false`.
- **RF-20.** La imagen `api` pasa a `0.2.0` en `compose.yaml` y en `k8s/brewtrack.yaml`.
- **RF-21 a RF-24b.** `k8s/monitoring.yaml`: Deployment y Service `ClusterIP` de `prometheus` y `grafana`, `namespace: brewtrack`, datos en `emptyDir`, configuración desde las ConfigMaps `prometheus-config`, `grafana-datasources`, `grafana-dashboards` y `grafana-alerting`, contraseña por `secretKeyRef`.
- **RF-26 a RF-28.** `k8s/README.md`, `README.md` y `AGENTS.md`.

## Datos

Sin migraciones.
