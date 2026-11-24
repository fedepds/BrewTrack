#!/usr/bin/env bash
# Levanta BrewTrack completo en minikube, de cero o sobre lo que ya exista. Se puede correr las veces que haga falta.
#
#   1. minikube (driver docker, containerd) y el addon ingress (operador ingress-nginx)
#   2. registro local de imágenes
#   3. build y push de db, api y web con etiqueta versión-commit
#   4. operadores: Kyverno (con sus políticas) y Falco
#   5. BrewTrack con Helm, helm test y primer admin
#   6. Prometheus y Grafana con el dashboard
#
# Variables: ADMIN_EMAIL (admin@brewtrack.local), ADMIN_PASSWORD (al azar si falta),
#            SKIP_FALCO=1 para no instalar Falco (necesita eBPF en el kernel del nodo).
# El admin queda en el Secret brewtrack-admin; scripts/load.sh lo lee de ahí.
set -euo pipefail
cd "$(dirname "$0")/.."

NS=brewtrack
PUSH=localhost:5001
PULL=brewtrack-registry:5000
COMMIT=$(git rev-parse --short=7 HEAD)
DB_TAG=0.1.0-$COMMIT API_TAG=0.1.0-$COMMIT WEB_TAG=0.2.0-$COMMIT
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@brewtrack.local}

step() { printf '\n===== [up] %s\n' "$*"; }

step "1/6 minikube e ingress-nginx"
if ! minikube status >/dev/null 2>&1; then
  minikube start --driver=docker --container-runtime=containerd --cpus=4 --memory=6g
fi
minikube addons enable ingress
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=300s

step "2/6 registro local"
bash scripts/registry-up.sh

step "3/6 build y push de imágenes ($COMMIT)"
docker build -t "$PUSH/brewtrack-db:$DB_TAG"   -f db/brewtrack-db.Containerfile db
docker build -t "$PUSH/brewtrack-api:$API_TAG" -f api/brewtrack-api.Containerfile api
docker build -t "$PUSH/brewtrack-web:$WEB_TAG" -f web/brewtrack-web.Containerfile web
for img in "brewtrack-db:$DB_TAG" "brewtrack-api:$API_TAG" "brewtrack-web:$WEB_TAG"; do
  docker push "$PUSH/$img"
done

step "4/6 operadores: Kyverno y Falco"
bash scripts/kyverno-up.sh
if [ "${SKIP_FALCO:-0}" = 1 ]; then echo "[up] Falco omitido (SKIP_FALCO=1)"; else bash scripts/falco-up.sh; fi

step "5/6 BrewTrack con Helm"
helm upgrade --install brewtrack ./helm-chart -n "$NS" --create-namespace \
  -f helm-chart/values-dev.yaml \
  --set db.image.repository=$PULL/brewtrack-db   --set db.image.tag="$DB_TAG" \
  --set api.image.repository=$PULL/brewtrack-api --set api.image.tag="$API_TAG" \
  --set web.image.repository=$PULL/brewtrack-web --set web.image.tag="$WEB_TAG" \
  --wait --timeout 5m
helm test brewtrack -n "$NS" --logs --timeout 2m

# Primer admin: la clave vive solo en el Secret, nunca en un archivo del repo.
if ! kubectl -n "$NS" get secret brewtrack-admin >/dev/null 2>&1; then
  ADMIN_PASSWORD=${ADMIN_PASSWORD:-$(openssl rand -hex 12)}
  # create-admin pide la clave con getpass; sin terminal la lee de stdin.
  printf '%s\n' "$ADMIN_PASSWORD" | kubectl -n "$NS" exec -i deploy/brewtrack-api -c api -- \
    python -m app.cli create-admin --email "$ADMIN_EMAIL" --name Admin
  kubectl -n "$NS" create secret generic brewtrack-admin \
    --from-literal=email="$ADMIN_EMAIL" --from-literal=password="$ADMIN_PASSWORD"
fi

step "6/6 Prometheus y Grafana"
bash scripts/monitoring-up.sh

step "listo"
kubectl -n "$NS" get pods,svc
cat <<EOF

Web:        kubectl -n $NS port-forward svc/brewtrack-web 8081:8080   → http://localhost:8081
Grafana:    kubectl -n $NS port-forward svc/grafana 3000:3000         → http://localhost:3000
Prometheus: kubectl -n $NS port-forward svc/prometheus 9090:9090      → http://localhost:9090/targets
Admin:      kubectl -n $NS get secret brewtrack-admin -o jsonpath='{.data.email}' | base64 -d
            kubectl -n $NS get secret brewtrack-admin -o jsonpath='{.data.password}' | base64 -d
Tráfico:    bash scripts/load.sh
Borrar:     bash scripts/down.sh
EOF
