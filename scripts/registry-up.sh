#!/usr/bin/env bash
# Levanta el registro local de imágenes y prepara minikube para bajar de él. Se puede correr las veces que haga falta.
#
#   Desde el host (docker push): localhost:5001/brewtrack-<x>:<tag>
#   Desde el clúster (pods):     brewtrack-registry:5000/brewtrack-<x>:<tag>
#
# Las dos direcciones llegan al mismo registro: el host usa el puerto publicado y el nodo de minikube
# lo encuentra por nombre porque los dos contenedores comparten la red "minikube" de Docker.
set -euo pipefail

NAME=brewtrack-registry
IMAGE=docker.io/library/registry:3.0.0
HOST_PORT=5001          # 5000 lo ocupa AirPlay en macOS y "flutter run" en este repo.
NODE=${MINIKUBE_NODE:-minikube}
IN_CLUSTER="$NAME:5000"

log() { printf '[registry] %s\n' "$*"; }

# 1. El registro.
if [ -z "$(docker ps -aq -f name="^${NAME}$")" ]; then
  log "creando $NAME ($IMAGE) en 127.0.0.1:$HOST_PORT"
  docker run -d --name "$NAME" --restart unless-stopped \
    -p "127.0.0.1:${HOST_PORT}:5000" \
    -v brewtrack-registry:/var/lib/registry \
    "$IMAGE" >/dev/null
elif [ -z "$(docker ps -q -f name="^${NAME}$")" ]; then
  log "arrancando $NAME"
  docker start "$NAME" >/dev/null
else
  log "$NAME ya está corriendo"
fi

# 2. Misma red que el nodo de minikube, para que lo resuelva por nombre.
if ! docker inspect "$NODE" >/dev/null 2>&1; then
  log "no encuentro el contenedor '$NODE'. Arranca minikube con: minikube start --driver=docker"
  exit 1
fi
NET=$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$NODE" | awk '{print $1}')
if ! docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$NAME" | grep -qw "$NET"; then
  log "conectando $NAME a la red $NET"
  docker network connect "$NET" "$NAME"
fi

# 3. El registro es HTTP: containerd del nodo tiene que aceptarlo para ese host.
# kubectl del propio nodo: no depende de tener kubectl ni kubeconfig en el host.
KVER=$(docker exec "$NODE" ls /var/lib/minikube/binaries | tail -1)
RUNTIME=$(docker exec "$NODE" "/var/lib/minikube/binaries/$KVER/kubectl" --kubeconfig=/etc/kubernetes/admin.conf \
  get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}')
case "$RUNTIME" in
  *containerd*)
    if ! docker exec "$NODE" grep -q 'config_path' /etc/containerd/config.toml; then
      log "containerd del nodo no tiene config_path; no puedo declarar el registro HTTP."
      exit 1
    fi
    log "declarando $IN_CLUSTER como registro HTTP en containerd del nodo"
    docker exec -i "$NODE" sh -c "mkdir -p '/etc/containerd/certs.d/$IN_CLUSTER' && cat > '/etc/containerd/certs.d/$IN_CLUSTER/hosts.toml'" <<EOF
server = "http://$IN_CLUSTER"

[host."http://$IN_CLUSTER"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
EOF
    ;;
  *)
    log "el nodo no usa containerd ($RUNTIME)."
    log "Recrea minikube aceptando el registro: minikube delete && minikube start --driver=docker --insecure-registry=$IN_CLUSTER"
    exit 1
    ;;
esac

# 4. Prueba de punta a punta: el nodo llega al registro.
if docker exec "$NODE" sh -c "curl -sf http://$IN_CLUSTER/v2/ >/dev/null"; then
  log "listo: el nodo llega a http://$IN_CLUSTER"
else
  log "el nodo no llega a http://$IN_CLUSTER"
  exit 1
fi
