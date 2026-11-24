#!/usr/bin/env bash
# Borra todo lo que crea scripts/up.sh: BrewTrack, monitoreo, operadores y registro local.
# Pide confirmación porque borra la base de datos. Se puede correr aunque falten partes.
#
#   bash scripts/down.sh            borra recursos y deja minikube encendido
#   bash scripts/down.sh --all      además borra el registro con sus imágenes y el clúster de minikube
#   YES=1 bash scripts/down.sh      sin pregunta
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

NS=brewtrack
ALL=0; [ "${1:-}" = --all ] && ALL=1
step() { printf '\n===== [down] %s\n' "$*"; }

if [ "${YES:-0}" != 1 ]; then
  read -r -p "Esto borra BrewTrack y su base de datos. ¿Seguir? [s/N] " ok
  [ "$ok" = s ] || [ "$ok" = S ] || { echo "cancelado"; exit 1; }
fi

step "BrewTrack (Helm)"
helm uninstall brewtrack -n "$NS" --wait 2>/dev/null || echo "no estaba instalado"

step "Prometheus y Grafana"
kubectl delete -f k8s/grafana.yaml -f k8s/prometheus.yaml --ignore-not-found

step "namespace $NS (PVC de la base, Secrets y lo que quede)"
# El Secret de la chart tiene resource-policy: keep; borrar el namespace lo elimina igual.
kubectl delete namespace "$NS" --ignore-not-found --wait

step "Falco"
helm uninstall falco -n falco --wait 2>/dev/null || echo "no estaba instalado"
kubectl delete namespace falco --ignore-not-found --wait

step "Kyverno y sus políticas"
kubectl delete -f kyverno/policies/ --ignore-not-found
helm uninstall kyverno -n kyverno --wait 2>/dev/null || echo "no estaba instalado"
kubectl delete namespace kyverno --ignore-not-found --wait

if [ "$ALL" = 1 ]; then
  step "registro local e imágenes"
  docker rm -f brewtrack-registry 2>/dev/null || true
  docker volume rm brewtrack-registry 2>/dev/null || true
  step "clúster de minikube"
  minikube delete
fi

step "listo"
[ "$ALL" = 1 ] || kubectl get namespaces
