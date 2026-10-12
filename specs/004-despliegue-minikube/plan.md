# 004 — Plan

## Constitución

| Regla | Cómo la cumple este cambio |
|---|---|
| Alcance | Suma un destino de despliegue (Minikube). Ninguna función nueva. |
| Stock | No toca cálculos. |
| Permisos | La API los sigue imponiendo. nginx solo reenvía. |
| Errores | Sin endpoints nuevos. Los errores de la API pasan sin cambios por `web`. |
| Esquema | Sin cambios. `api` corre `alembic upgrade head` al arrancar, también en el clúster. |
| Secretos | Ningún archivo versionado trae el Secret ni sus valores. La persona lo crea desde `.env` con `kubectl create secret`. |

## Diseño

- **RF-1/RF-2.** La plantilla usa `http://${API_HOST}:8000`. El script `web/docker-entrypoint.d/10-api-host.envsh` (ejecutable, lo carga el entrypoint de nginx antes de `envsubst`) hace `export API_HOST="${API_HOST:-api}"`. Así la imagen no define la variable y el contenedor en compose no la muestra (CA-3). `$api_upstream`, `$host` y `$proxy_add_x_forwarded_for` no cambian.
- **RF-4.** La imagen `web` pasa a `0.1.1` en `compose.yaml` y en los manifiestos. `api` sigue en `0.1.0`. `imagePullPolicy: Never`.
- **RF-3/5.** `k8s/namespace.yaml` (Namespace) y `k8s/brewtrack.yaml` (PVC, y Deployment y Service de `db`, `api`, `web`). Todos con `namespace: brewtrack`. `web` fija `API_HOST=api.brewtrack.svc.cluster.local`.
- **RF-6/7.** PVC `brewtrack-pgdata`, 1Gi, `ReadWriteOnce`. `db` usa `strategy: Recreate`. Quitar la aplicación borra solo Deployments y Services.
- **RF-8.** Services `ClusterIP`. Sin `hostPort`. Acceso desde el host con `kubectl port-forward`.
- **RF-10/11.** `readinessProbe`: `pg_isready` en `db`, `GET /api/v1/health` en `api`, `GET /` en `web`. `api` se reinicia solo si `db` aún no responde.
- **RF-12/13/14.** `POSTGRES_PASSWORD` y `JWT_SECRET` salen de `secretKeyRef` a `brewtrack-secrets`. `DATABASE_URL` se arma con `$(POSTGRES_PASSWORD)`. `TIMEZONE` y `SEED_DEMO_LOTS` con los valores por defecto de compose.
- **RF-16/17.** `k8s/README.md` con los diez pasos. `AGENTS.md` enlaza esa guía en "Comandos".

## Datos

Sin migraciones.
