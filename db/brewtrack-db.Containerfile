# postgres oficial con los parches de Alpine que la imagen aún no trae (Trivy).
# Motivo y riesgo aceptado (gosu): docs/security/2026-11-10-imagen-db.md
FROM docker.io/library/postgres:17.11-alpine3.24
RUN apk upgrade --no-cache
# El entrypoint oficial admite arrancar sin root; k8s ya usa este uid (70).
USER postgres
