# 004 — Notas del developer

## Qué cambió
- `web/templates/default.conf.template`: `http://${API_HOST}:8000`.
- `web/docker-entrypoint.d/10-api-host.envsh` (nuevo, ejecutable): `API_HOST` vale `api` si no existe. Variable elegida: `API_HOST`.
- `web/brewtrack-web.Containerfile`: copia el script con `--chmod=755`.
- `compose.yaml`: imagen `web` en `0.1.1`.
- `k8s/namespace.yaml`, `k8s/brewtrack.yaml`, `k8s/README.md` (nuevos).
- `AGENTS.md`: línea de Minikube en "Comandos".

## Cómo probarlo
- Compose: `podman compose up --build -d`, luego `curl localhost:8080/api/v1/health`.
- Manifiestos: `kubectl apply --dry-run=client -f k8s/`.
- Clúster (QA): sigue `k8s/README.md`. Las imágenes `localhost/brewtrack-api:0.1.0` y `localhost/brewtrack-web:0.1.1` deben estar cargadas con `minikube image load`. La `web:0.1.1` es nueva: la persona debe cargarla.

## Pendiente
- Nada probado en el clúster (RF-18). `db` usa `PGDATA=/var/lib/postgresql/data/pgdata`, para evitar fallos si el volumen trae `lost+found`.
- Un Pod `api` puede reiniciarse mientras `db` arranca (RF-11); sin initContainer.

## Preguntas abiertas
Ninguna.
