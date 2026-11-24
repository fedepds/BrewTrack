#!/usr/bin/env bash
# Instala Falco con su chart oficial en el namespace falco. Se puede correr las veces que haga falta.
# Falco corre privilegiado para leer las llamadas al sistema del nodo: por eso su namespace queda fuera de Kyverno.
set -euo pipefail
cd "$(dirname "$0")/.."

CHART_VERSION=9.2.2   # Falco 0.45.2
log() { printf '[falco] %s\n' "$*"; }

helm repo add falcosecurity https://falcosecurity.github.io/charts >/dev/null 2>&1 || true
helm repo update falcosecurity >/dev/null

log "instalando Falco (chart $CHART_VERSION)"
helm upgrade --install falco falcosecurity/falco -n falco --create-namespace --version "$CHART_VERSION" \
  -f falco/values.yaml --wait --timeout 10m

kubectl -n falco rollout status ds/falco --timeout=300s
# Falco escribe "Opening 'syscall' source" cuando ya está leyendo eventos del kernel.
for _ in $(seq 1 30); do
  if kubectl -n falco logs ds/falco -c falco --tail=200 2>/dev/null | grep -q "Opening 'syscall' source"; then
    log "listo: Falco está leyendo eventos del kernel"
    exit 0
  fi
  sleep 2
done
log "Falco arrancó pero no confirmó la fuente de eventos. Revisa: kubectl -n falco logs ds/falco -c falco"
exit 1
