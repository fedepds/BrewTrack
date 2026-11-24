#!/usr/bin/env bash
# Instala Kyverno con su chart oficial y aplica las políticas de kyverno/policies/.
# Se puede correr las veces que haga falta.
set -euo pipefail
cd "$(dirname "$0")/.."

CHART_VERSION=3.9.2   # Kyverno v1.19.2; las políticas ValidatingPolicy piden 1.19.1 o más.
log() { printf '[kyverno] %s\n' "$*"; }

helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null 2>&1 || true
helm repo update kyverno >/dev/null

log "instalando Kyverno (chart $CHART_VERSION)"
# Una réplica de cada controlador alcanza para minikube.
helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace --version "$CHART_VERSION" \
  --set admissionController.replicas=1 \
  --set backgroundController.replicas=1 \
  --set cleanupController.replicas=1 \
  --set reportsController.replicas=1 \
  --wait --timeout 5m

log "aplicando políticas"
# --wait espera los pods, no al webhook que valida políticas: en una instalación nueva rechaza conexiones unos segundos.
for i in $(seq 1 30); do
  kubectl apply -f kyverno/policies/ && break
  [ "$i" = 30 ] && { log "el webhook de Kyverno no respondió en 60 s"; exit 1; }
  sleep 2
done

# El webhook tarda unos segundos en tomar las políticas nuevas: espera a que rechace un pod que debe rechazar.
log "esperando a que las políticas estén activas"
for _ in $(seq 1 30); do
  if ! kubectl apply --dry-run=server -f kyverno/tests/pod-latest.yaml >/dev/null 2>&1; then
    log "listo: Kyverno ya rechaza pods que incumplen"
    kubectl get validatingpolicies
    exit 0
  fi
  sleep 2
done
log "las políticas no se activaron en 60 s. Revisa: kubectl get validatingpolicies -o yaml"
exit 1
