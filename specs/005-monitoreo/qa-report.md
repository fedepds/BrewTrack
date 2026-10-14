# 005 — Informe de QA

Veredicto: APROBADO CON OBSERVACIONES

El hallazgo bloqueante de la ronda anterior (RF-11, CA-12) está arreglado y lo verifiqué de punta a punta. Las pruebas en Minikube quedan pendientes de decisión de la persona (RF-25).

## Criterios de aceptación

| CA | Resultado | Evidencia |
|---|---|---|
| 1 | Cumple | `test_metrics_text_format` pasa; `/metrics` dentro del contenedor `api` responde 200 en texto |
| 2 | Cumple | `test_failed_login_counted` pasa |
| 3 | Cumple | `test_health_and_metrics_not_counted` pasa |
| 4 | Cumple | `test_route_template_without_uuid` pasa |
| 5 | Cumple | `test_unknown_urls_not_in_metrics` pasa (ruta `none`) |
| 6 | Cumple | `test_metrics_not_in_openapi` pasa |
| 7 | Cumple | `podman run --entrypoint promtool prom/prometheus:v3.5.0 check config /m/prometheus.yml`: SUCCESS, rc 0 |
| 8 | Cumple | `curl localhost:8081/metrics`: sirve el `index.html` de la SPA; 0 apariciones de `http_request` |
| 9 | Cumple | `podman port`: `grafana` 3000 -> `127.0.0.1:3001`; `prometheus` sin puertos |
| 10 | Cumple | `/api/search` sin credenciales: 401; `/` redirige a `/login` |
| 11 | Cumple | Sin pasos a mano: fuente `Prometheus` (`http://prometheus:9090`), panel "BrewTrack API" con 5 gráficos, 6 alertas con los nombres de RF-10 (API de Grafana) |
| 12 | Cumple | `compose restart api`; antes de los logins Prometheus ya tenía las series 401 en 0. 11 logins fallidos por `web:8081` a las 19:30:58; "Fuerza bruta" en `firing` a las 19:32:03 (65 s). `increase()` = 11,19 |
| 13 | Cumple | Último login fallido 19:30:59; a las 19:41:04 las 6 alertas en `inactive`. No medí el instante exacto de la vuelta a normal |
| 14 | Cumple | `compose stop api` a las 19:41:14: `pending` 19:41:54, `firing` 19:43:44 (2 min 30 s) |
| 15 | Cumple | Stack arriba 19:19 sin pedidos a la API; a las 19:30 las 6 alertas `inactive` y con salud `ok` |
| 16 | Cumple | Copia en el scratchpad; `params: [10]` -> `[3]` solo en "Fuerza bruta"; reinicio de `grafana`; 4 logins fallidos a las 20:38:07; `firing` a las 20:38:57 (50 s). Sin reconstruir `api`. Restauré el archivo: `diff -r` y `cmp` contra la copia sin diferencias |
| 17 | Cumple | `GRAFANA_ADMIN_PASSWORD=` vacía: `grafana` sale con código 1 y el log dice "Falta GRAFANA_ADMIN_PASSWORD en .env" |
| 18 | Cumple | `compose.yaml` y `k8s/monitoring.yaml`: `prom/prometheus:v3.5.0` y `grafana/grafana:12.2.0` |
| 19 | Pendiente de decisión (RF-25) | Minikube está parado. `kubectl apply --dry-run=client` falla por no llegar al servidor (también con `--validate=false`). No lo arranqué. Los tres YAML de `k8s/` se leen bien por inspección |
| 20 | Cumple (por lectura) | `k8s/monitoring.yaml`: 4 objetos con `namespace: brewtrack`; sin `hostPort`, `NodePort`, `LoadBalancer`, ConfigMap ni Secret; `emptyDir` en ambos |
| 21 | Cumple | `git grep GRAFANA_ADMIN_PASSWORD`: solo nombres de variable y `.env.example` con valor vacío; en Minikube entra por `secretKeyRef` |
| 22 a 26 (incluido 25b) | Pendiente de decisión (RF-25) | No probé en clúster. El namespace `brewtrack` ya existe en Minikube por la spec 004 |
| 27 | Cumple (por lectura) | `k8s/README.md`: pasos de RF-26 en orden; el Secret entra con `grep` sobre `.env` y nada muestra un valor |
| 28 | Cumple (por lectura) | `AGENTS.md` línea 21 (Grafana); aviso de contraseña en `README.md` y `k8s/README.md` |
| 29 | Cumple | `cd api && pytest`: 103 pasan; `flutter analyze`: sin problemas; `flutter test`: 15 pasan; `/api/v1/health` por `web`: 200 |

## Constitución

| Regla | Resultado | Evidencia |
|---|---|---|
| Alcance | Cumple | Solo tráfico HTTP; sin métricas de negocio, curvas, empaque, venta, recetas, cata ni multi-empresa |
| Stock calculado | No aplica | Sin cambios; `models.py` y migraciones intactos (`git status`) |
| Permisos en la API | Cumple | Sin endpoints nuevos en `/api/v1`; `/metrics` fuera de `/api/v1`, sin salir por `web` (CA-8); Grafana exige login (CA-10) |
| Formato de error | Cumple | `/metrics` es texto de Prometheus; los errores de `/api/v1` no cambian (401 de login visto con su formato por los tests existentes) |
| Migraciones | No aplica | Sin cambios de esquema |
| Secretos | Cumple | `.env` no se leyó; la contraseña de prueba solo viajó en el entorno de mis comandos; `.env.example` vacío; sin valores versionados |
| Imagen `api` sin root y health con la imagen sola | Cumple | `podman exec brewtrack2-api-1 id`: `uid=1000(app)`; health 200 |
| Idioma de comentarios y redacción | Pendiente de revisión humana | Aprueba el PR la persona usuaria |

## Hallazgos

Sin fallos abiertos. Observaciones:

1. Baja (informativa). El puerto de `web` pasó de 8080 a 8081 en `compose.yaml` (`ports: "8081:80"`), y en documentos varios. La spec 005 no lo pide. La persona decide si lo acepta en esta rama o lo separa.
2. Baja. CA-13 comprobado en un punto (10 min después), no el instante exacto de la vuelta a normal. La ventana de `increase()` es de 5 min, así que vuelve antes.
3. Baja. `kubectl apply --dry-run=client` necesita el clúster en marcha incluso con `--validate=false`. CA-19 queda para cuando la persona arranque Minikube.

## Criterios sin prueba

CA-19 y CA-22 a CA-26 (incluido CA-25b): pendientes de decisión de la persona (RF-25). CA-20, CA-27 y CA-28: solo por lectura. Revisión humana de redacción y comentarios.

## Estado al terminar

Borré el contenedor `brewtrack2-grafana-1` y el volumen `brewtrack2_grafanadata` (`podman volume ls` ya no los lista). Quedan arriba `db`, `api`, `web` y `prometheus` de BrewTrack, con `brewtrack2_promdata`. No toqué el `grafana` ajeno del puerto 3000. `monitoring/` quedó igual (`cmp`).

## Pruebas en Minikube (2026-10-14)

Por decisión de la persona (PA-2), el developer probó en el namespace `brewtrack` de la persona y no lo borró. CA-26 no aplica.

| CA | Resultado | Evidencia |
|---|---|---|
| 19 | Cumple | `kubectl apply --dry-run=client -f k8s/`: código 0. Los objetos salen `unchanged` o `configured` y no `created`, porque el namespace ya existe |
| 22 | Cumple | `kubectl rollout status` de `db`, `api`, `web`, `prometheus` y `grafana`: 67 s |
| 23 | Cumple | `port-forward` en 3002: fuente `Prometheus` (`http://prometheus:9090`), panel "BrewTrack API" con 5 gráficos, 6 alertas con los nombres de RF-10. Target `api:8000/metrics` en `up` |
| 24 | Cumple | 11 logins fallidos por `web` a las 17:19:10 UTC; "Fuerza bruta" activa a las 17:20:20 (70 s) |
| 25 | Cumple | `GET /api/search` sin credenciales: 401 |
| 25b | Cumple | Pod de `grafana` borrado; el nuevo queda listo en segundos; login con la contraseña del Secret: 200; misma fuente, 5 gráficos y 6 alertas. Único PVC: `brewtrack-pgdata` |
| 26 | No aplica | Decisión de la persona (PA-2) |

Hallazgo arreglado: la línea 1 de `k8s/brewtrack.yaml` empezaba con `~#`. YAML la leía como clave y `kubectl apply` rechazaba el PVC con "unknown field". El dry-run de cliente no lo detecta. Se cambió a `#`.

Estado al terminar: el namespace `brewtrack` queda con `db`, `api` (0.2.0), `web`, `prometheus` y `grafana` en marcha, sin port-forwards abiertos.
