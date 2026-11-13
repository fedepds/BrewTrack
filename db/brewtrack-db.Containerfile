# postgres oficial con los parches de Alpine que la imagen aún no trae (Trivy).
# Motivo y riesgo aceptado (gosu): docs/security/2026-11-10-imagen-db.md
FROM docker.io/library/postgres:17-alpine
RUN apk upgrade --no-cache
