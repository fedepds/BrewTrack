# 004 — Tareas

- [x] T1. Plantilla nginx con `${API_HOST}` y script `10-api-host.envsh` con valor por defecto `api` (RF-1, RF-2, CA-3).
- [x] T2. Etiqueta `web` `0.1.1` en `compose.yaml` y en el Containerfile copia el script (RF-4).
- [x] T3. `k8s/namespace.yaml` (RF-5, CA-7).
- [x] T4. `k8s/brewtrack.yaml`: PVC, `db`, `api`, `web` (RF-3 a RF-14, CA-5, CA-7).
- [x] T5. `k8s/README.md` con los diez pasos y línea en `AGENTS.md` (RF-16, RF-17, CA-18).
- [x] T6. Verificar: `kubectl apply --dry-run=client` (CA-4), compose (CA-1 a CA-3), pytest, flutter (CA-19).
