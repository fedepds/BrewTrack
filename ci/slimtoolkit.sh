#!/usr/bin/env bash
# SlimToolkit para BrewTrack (spec 010). Lo llama el Jenkinsfile y se corre igual en local.
#
#   ci/slimtoolkit.sh xray   DB_REF API_REF WEB_REF   # informes de capas de las tres imágenes
#   ci/slimtoolkit.sh reduce DB_REF API_REF WEB_REF   # imagen web reducida: <WEB_REF>-slim, probada con curl
#
# Una REF es repositorio:etiqueta, por ejemplo localhost:5001/brewtrack-api:0.1.0-abc1234.
# Los informes quedan en reports/slimtoolkit/, con la imagen y su etiqueta en el nombre.
#
# slim 1.40.11 no puede leer imágenes del Docker del host: con el almacén containerd (por defecto
# desde Docker 25) falla al exportarlas. Por eso el script levanta un dockerd desechable (docker:dind,
# almacén clásico, sin puertos en el host), le carga las imágenes y corre slim contra él.
set -euo pipefail

MODE=${1:?uso: ci/slimtoolkit.sh xray|reduce DB_REF API_REF WEB_REF}
DB_REF=${2:?falta DB_REF}
API_REF=${3:?falta API_REF}
WEB_REF=${4:?falta WEB_REF}

SLIM_IMAGE=${SLIM_IMAGE:-docker.io/dslim/slim:1.40.11}
DIND_IMAGE=${DIND_IMAGE:-docker.io/library/docker:29.10.0-dind}
CURL_IMAGE=${CURL_IMAGE:-docker.io/curlimages/curl:8.11.1}
# Rutas que la imagen reducida debe servir con 200: raíz, index, una ruta interna de la SPA y el JS de la app.
WEB_CHECK_PATHS=${WEB_CHECK_PATHS:-"/ /index.html /lotes/ejemplo /main.dart.js"}

OUT=reports/slimtoolkit
DIND=brewtrack-slim-dind
mkdir -p "$OUT"

log() { printf '[slimtoolkit] %s\n' "$*"; }

cleanup() {
  docker rm -f "$DIND" >/dev/null 2>&1 || true
  rm -rf "$OUT/.state"   # guarda un .tar de cada imagen analizada
}
trap cleanup EXIT

# Nombre de archivo: brewtrack-api:0.1.0-abc1234 -> brewtrack-api-0.1.0-abc1234
file_name() { local r=${1##*/}; echo "${r/:/-}"; }

# Última imagen base (FROM) del Containerfile de la imagen. slim usa la base para separar capas heredadas.
base_of() {
  local n=${1##*/}; n=${n%%:*}; n=${n#brewtrack-}
  sed -n 's/^FROM \([^ ]*\).*/\1/p' "$n/brewtrack-$n.Containerfile" | tail -1
}

start_dind() {
  docker rm -f "$DIND" >/dev/null 2>&1 || true
  docker run -d --privileged --name "$DIND" -e DOCKER_TLS_CERTDIR= "$DIND_IMAGE" \
    --feature containerd-snapshotter=false >/dev/null
  for _ in $(seq 1 30); do
    docker exec "$DIND" docker info >/dev/null 2>&1 && return 0
    sleep 1
  done
  log "el dockerd interno no arrancó"; return 1
}

# Pasa imágenes del Docker del host al dockerd interno (baja la base si el host no la tiene).
load() {
  local ref
  for ref in "$@"; do
    docker image inspect "$ref" >/dev/null 2>&1 || docker pull -q "$ref" >/dev/null
  done
  docker save "$@" | docker exec -i "$DIND" docker load >/dev/null
}

# slim REPORTE subcomando args...  (corre como el usuario actual para no dejar archivos de root en reports/)
slim() {
  local report=$1; shift
  docker run --rm -u "$(id -u):$(id -g)" --network "container:$DIND" -v "$PWD/$OUT:/out" "$SLIM_IMAGE" \
    --crt-api-version 1.45 --host tcp://127.0.0.1:2375 --tls=false --tls-verify=false \
    --state-path /out/.state --report "/out/$report" "$@"
}

summarize() {  # JSON de xray + base -> resumen de texto (las primeras N instrucciones son de la base)
  docker run --rm -u "$(id -u):$(id -g)" -v "$PWD/ci:/ci:ro" -v "$PWD/$OUT:/out" python:3.13-slim \
    python -I /ci/slimtoolkit-summary.py "/out/$1.xray.json" "$2" "$(docker history -q "$2" | wc -l)" > "$OUT/$1.txt"
}

do_xray() {
  local rc=0 ref name base
  start_dind
  for ref in "$DB_REF" "$API_REF" "$WEB_REF"; do
    name=$(file_name "$ref"); base=$(base_of "$ref")
    log "xray $ref"
    if load "$ref" "$base" \
      && slim "$name.xray.json" xray --target "$ref" --changes all --changes-output report > "$OUT/$name.xray.log" 2>&1 \
      && summarize "$name" "$base"; then
      sed -n '2p' "$OUT/$name.txt"
    else
      log "xray falló en $ref (ver $OUT/$name.xray.log)"; rc=1
    fi
  done
  return $rc
}

do_reduce() {
  local repo=${WEB_REF%:*} tag=${WEB_REF##*:} slim_ref name base code path
  slim_ref="$repo:$tag-slim"; name=$(file_name "$WEB_REF"); base=$(base_of "$WEB_REF")
  start_dind
  load "$WEB_REF" "$base"

  log "build $slim_ref"
  local probes=() paths=()
  for path in $WEB_CHECK_PATHS; do probes+=(--http-probe-cmd "$path"); done
  slim "$name.build.json" build --target "$WEB_REF" --tag "$slim_ref" --show-clogs \
    --http-probe-ports 8080 "${probes[@]}" \
    --include-path /usr/share/nginx/html --include-path /etc/nginx \
    --include-path /docker-entrypoint.sh --include-path /docker-entrypoint.d --include-shell \
    > "$OUT/$name.build.log" 2>&1 || { log "slim build falló (ver $OUT/$name.build.log)"; return 1; }

  log "prueba HTTP de $slim_ref"
  docker exec "$DIND" docker run -d --name web-slim -p 18080:8080 "$slim_ref" >/dev/null
  local user; user=$(docker exec "$DIND" docker inspect -f '{{.Config.User}}' "$slim_ref")
  [ "$user" = nginx ] || { log "la imagen reducida corre como '$user', no como nginx"; return 1; }
  for path in $WEB_CHECK_PATHS; do
    code=$(docker run --rm --network "container:$DIND" "$CURL_IMAGE" -s -o /dev/null -w '%{http_code}' \
      --retry 10 --retry-delay 1 --retry-connrefused "http://127.0.0.1:18080$path" || true)
    log "GET $path -> $code"
    [ "$code" = 200 ] || { docker exec "$DIND" docker logs web-slim 2>&1 | tail -5; return 1; }
  done

  local normal slimmed
  normal=$(docker exec "$DIND" docker image inspect -f '{{.Size}}' "$WEB_REF")
  slimmed=$(docker exec "$DIND" docker image inspect -f '{{.Size}}' "$slim_ref")
  printf '%s\n%s\n%s\n' \
    "web normal  $(( normal / 1000000 )) MB  $WEB_REF" \
    "web reducida $(( slimmed / 1000000 )) MB  $slim_ref" \
    "ahorro $(( (normal - slimmed) / 1000000 )) MB ($(( (normal - slimmed) * 100 / normal ))%)" \
    | tee "$OUT/$name.compare.txt"

  # Solo si todo pasó la imagen reducida llega al Docker del host.
  docker exec "$DIND" docker save "$slim_ref" | docker load >/dev/null
}

case $MODE in
  xray) do_xray ;;
  reduce) do_reduce ;;
  *) echo "modo desconocido: $MODE (xray o reduce)" >&2; exit 2 ;;
esac
