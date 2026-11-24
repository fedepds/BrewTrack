#!/usr/bin/env bash
# Despliega Prometheus y Grafana en el namespace brewtrack con el dashboard de grafana/dashboard.json.
# Se puede correr las veces que haga falta: también sirve para actualizar el dashboard.
set -euo pipefail
cd "$(dirname "$0")/.."

NS=brewtrack
log() { printf '[monitoring] %s\n' "$*"; }

kubectl get namespace "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS"

# Clave de admin de Grafana: se genera una vez y nunca se escribe en un archivo del repo.
if ! kubectl -n "$NS" get secret grafana >/dev/null 2>&1; then
  kubectl -n "$NS" create secret generic grafana --from-literal=admin-password="$(openssl rand -hex 16)"
  log "Secret grafana creado. Clave: kubectl -n $NS get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d"
fi

kubectl apply -f k8s/prometheus.yaml
kubectl -n "$NS" create configmap grafana-dashboards --from-file=brewtrack.json=grafana/dashboard.json \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/grafana.yaml

kubectl -n "$NS" rollout status deploy/prometheus --timeout=180s
kubectl -n "$NS" rollout status deploy/grafana --timeout=180s

log "listo. Abrir:"
log "  kubectl -n $NS port-forward svc/grafana 3000:3000      # http://localhost:3000 (usuario admin)"
log "  kubectl -n $NS port-forward svc/prometheus 9090:9090   # http://localhost:9090/targets"
