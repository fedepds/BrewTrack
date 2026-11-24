#!/usr/bin/env bash
# SlimToolkit para BrewTrack (spec 010). Lo llama el Jenkinsfile y se corre igual en local.
#
#   ci/slimtoolkit.sh xray   DB_REF API_REF WEB_REF   # informes de capas de las tres imágenes
#   ci/slimtoolkit.sh reduce DB_REF API_REF WEB_REF   # imagen web reducida: <WEB_REF>-slim, probada con curl
#
# Una REF es repositorio:etiqueta, por ejemplo localhost:5001/brewtrack-api:0.1.0-abc1234.
# Los informes quedan en reports/slimtoolkit/, con la imagen y su etiqueta en el nombre.
#
# slim 1.40.11 no lee imágenes del almacén containerd del Docker del host (falla al exportarlas).
# Por eso el script levanta un dockerd desechable (docker:dind con almacén clásico y --privileged,
# sin puertos en el host; riesgo en docs/security/2026-11-23-slimtoolkit-dind.md), le carga las imágenes
# y corre ahí dentro el binario oficial de slim. Nada se monta desde $PWD: Jenkins corre en un
# contenedor y su ruta de trabajo no existe en el host de Docker. Los datos salen con docker exec y stdin/stdout.
set -euo pipefail

MODE=${1:?uso: ci/slimtoolkit.sh xray|reduce DB_REF API_REF WEB_REF}
DB_REF=${2:?falta DB_REF}
API_REF=${3:?falta API_REF}
WEB_REF=${4:?falta WEB_REF}

SLIM_VERSION=1.40.11
SLIM_URL_BASE="https://github.com/slimtoolkit/slim/releases/download/$SLIM_VERSION"
# sha256 de cada release, calculado al fijar la versión. Si cambias SLIM_VERSION, recalcúlalos.
SLIM_SHA_AMD64=cb481010e1dfaf3ad465f89f7a6b05b1dfa5165ed4c4370bed7778c6324ad341
SLIM_SHA_ARM64=4a45e676d00e17dfd6eb64ea0d963a465d91002dfd39b5fccb0ec9ff04368edc
DIND_IMAGE=${DIND_IMAGE:-docker.io/library/docker:29.10.0-dind}
CURL_IMAGE=${CURL_IMAGE:-docker.io/curlimages/curl:8.11.1}
SUMMARY_IMAGE=${SUMMARY_IMAGE:-docker.io/library/python:3.13-slim}
# Rutas que la imagen reducida debe servir con 200: raíz, index, una ruta interna de la SPA y el JS de la app.
WEB_CHECK_PATHS=${WEB_CHECK_PATHS:-"/ /index.html /lotes/ejemplo /main.dart.js"}

OUT=reports/slimtoolkit
DIND=brewtrack-slim-dind
mkdir -p "$OUT"

log() { printf '[slimtoolkit] %s\n' "$*"; }
indind() { docker exec "$DIND" "$@"; }

trap 'docker rm -f "$DIND" >/dev/null 2>&1 || true' EXIT

# Nombre de archivo: localhost:5001/brewtrack-api:0.1.0-abc1234 -> brewtrack-api-0.1.0-abc1234
file_name() { local r=${1##*/}; echo "${r/:/-}"; }

# Última imagen base (FROM) del Containerfile de la imagen.
base_of() {
  local n=${1##*/}; n=${n%%:*}; n=${n#brewtrack-}
  sed -n 's/^FROM \([^ ]*\).*/\1/p' "$n/brewtrack-$n.Containerfile" | tail -1
}

# Levanta el dockerd interno y le instala el slim oficial, verificado con sha256.
start_dind() {
  local asset sha
  case "$(uname -m)" in
    x86_64) asset=dist_linux; sha=$SLIM_SHA_AMD64 ;;
    aarch64|arm64) asset=dist_linux_arm64; sha=$SLIM_SHA_ARM64 ;;
    *) log "arquitectura no soportada: $(uname -m)"; return 1 ;;
  esac
  docker rm -f "$DIND" >/dev/null 2>&1 || true
  docker run -d --privileged --name "$DIND" -e DOCKER_TLS_CERTDIR= "$DIND_IMAGE" \
    --feature containerd-snapshotter=false >/dev/null
  for _ in $(seq 1 30); do indind docker info >/dev/null 2>&1 && break; sleep 1; done
  indind docker info >/dev/null 2>&1 || { log "el dockerd interno no arrancó"; return 1; }
  indind sh -c "wget -qO /tmp/slim.tgz '$SLIM_URL_BASE/$asset.tar.gz' \
    && echo '$sha  /tmp/slim.tgz' | sha256sum -c - >/dev/null \
    && mkdir -p /opt/slim && tar xzf /tmp/slim.tgz -C /opt/slim --strip-components=1 \
    && rm /tmp/slim.tgz" || { log "no se pudo instalar slim $SLIM_VERSION (descarga o sha256)"; return 1; }
}

# Pasa imágenes del Docker del host al dockerd interno (baja la base si el host no la tiene).
load() {
  local ref
  for ref in "$@"; do
    docker image inspect "$ref" >/dev/null 2>&1 || docker pull -q "$ref" >/dev/null
  done
  docker save "$@" | docker exec -i "$DIND" docker load >/dev/null
}

# slim INFORME subcomando args...: corre slim dentro del dockerd interno y copia el informe a reports/.
# Devuelve el código de slim, pero copia el informe aunque falle.
slim() {
  local report=$1 rc=0; shift
  indind rm -rf /work; indind mkdir /work
  indind /opt/slim/slim --crt-api-version 1.45 --state-path /work/state --report "/work/$report" "$@" || rc=$?
  indind cat "/work/$report" > "$OUT/$report" 2>/dev/null || true
  return $rc
}

summarize() {  # JSON de xray (stdin) + base -> resumen de texto (las primeras N instrucciones son de la base)
  docker run --rm -i "$SUMMARY_IMAGE" python -I -c "$(cat ci/slimtoolkit-summary.py)" \
    "$1" "$(docker history -q "$1" | wc -l)" < "$OUT/$2.xray.json" > "$OUT/$2.txt"
}

do_xray() {
  local rc=0 ref name base
  start_dind
  for ref in "$DB_REF" "$API_REF" "$WEB_REF"; do
    name=$(file_name "$ref"); base=$(base_of "$ref")
    log "xray $ref"
    if load "$ref" "$base" \
      && slim "$name.xray.json" xray --target "$ref" --changes all --changes-output report > "$OUT/$name.xray.log" 2>&1 \
      && summarize "$base" "$name"; then
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
  local probes=()
  for path in $WEB_CHECK_PATHS; do probes+=(--http-probe-cmd "$path"); done
  slim "$name.build.json" build --target "$WEB_REF" --tag "$slim_ref" --show-clogs \
    --http-probe-ports 8080 "${probes[@]}" \
    --include-path /usr/share/nginx/html --include-path /etc/nginx \
    --include-path /docker-entrypoint.sh --include-path /docker-entrypoint.d --include-shell \
    > "$OUT/$name.build.log" 2>&1 || { log "slim build falló (ver $OUT/$name.build.log)"; return 1; }

  log "prueba HTTP de $slim_ref"
  indind docker run -d --name web-slim -p 18080:8080 "$slim_ref" >/dev/null
  local user; user=$(indind docker inspect -f '{{.Config.User}}' "$slim_ref")
  [ "$user" = nginx ] || { log "la imagen reducida corre como '$user', no como nginx"; return 1; }
  for path in $WEB_CHECK_PATHS; do
    code=$(docker run --rm --network "container:$DIND" "$CURL_IMAGE" -s -o /dev/null -w '%{http_code}' \
      --retry 10 --retry-delay 1 --retry-connrefused "http://127.0.0.1:18080$path" || true)
    log "GET $path -> ${code:-sin respuesta}"
    [ "$code" = 200 ] || { indind docker logs web-slim 2>&1 | tail -5; return 1; }
  done

  local normal slimmed
  normal=$(indind docker image inspect -f '{{.Size}}' "$WEB_REF")
  slimmed=$(indind docker image inspect -f '{{.Size}}' "$slim_ref")
  printf '%s\n%s\n%s\n' \
    "web normal   $(( normal / 1000000 )) MB  $WEB_REF" \
    "web reducida $(( slimmed / 1000000 )) MB  $slim_ref" \
    "ahorro $(( (normal - slimmed) / 1000000 )) MB ($(( (normal - slimmed) * 100 / normal ))%)" \
    | tee "$OUT/$name.compare.txt"

  # Solo si todo pasó la imagen reducida llega al Docker del host.
  indind docker save "$slim_ref" | docker load >/dev/null
}

case $MODE in
  xray) do_xray ;;
  reduce) do_reduce ;;
  *) echo "modo desconocido: $MODE (xray o reduce)" >&2; exit 2 ;;
esac
