#!/bin/sh
# Analiza imágenes con SlimToolkit contra un Docker 27 temporal (spec 007, D-1).
# Uso: scripts/slim-analysis.sh <salida.md> <imagen>...
# Falla si falta algún dato de alguna imagen (RF-16). Borra el Docker temporal al salir (RF-14).
set -eu
OUT=$1; shift
D="slim-dind-${BUILD_NUMBER:-$$}"
SLIM=dslim/slim:1.40.11
TMP=$(mktemp -d)
cleanup() { docker rm -f "$D" >/dev/null 2>&1 || true; rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

# Sin -p: el Docker temporal no publica puertos en el host.
docker run -d --privileged --name "$D" -e DOCKER_TLS_CERTDIR= docker:27.5.1-dind >/dev/null
n=0
until docker exec "$D" docker info >/dev/null 2>&1; do
  n=$((n + 1)); [ "$n" -le 60 ] || { echo "dind no arrancó" >&2; exit 1; }
  sleep 2
done

{ echo "# Análisis de imágenes (SlimToolkit)"; echo; echo "Generado: $(date -u +%F)"; } > "$OUT"
for img in "$@"; do
  docker save "$img" | docker exec -i "$D" docker load >/dev/null
  docker run --rm --platform linux/amd64 --network "container:$D" -e DOCKER_HOST=tcp://127.0.0.1:2375 \
    "$SLIM" --check-version=false xray --changes none "$img" > "$TMP/log" 2>&1 \
    || { echo "slim falló con $img" >&2; exit 1; }
  size=$(docker exec "$D" docker image inspect "$img" --format '{{.Size}}')
  layers=$(sed -n "s/.*info=layers.count value='\([0-9]*\)'.*/\1/p" "$TMP/log" | head -1)
  dup=$(grep 'info=image.stats.duplicates' "$TMP/log" | sed -n "s/.* wasted.bytes='\([0-9]*\)'.*/\1/p" | head -1)
  shells=$(grep -c 'info=image.shells' "$TMP/log" || true)
  setuid=$(grep -c 'info=image.special_perms.setuid' "$TMP/log" || true)
  big=$(docker exec "$D" docker history --human=false --no-trunc --format '{{.Size}}|{{json .CreatedBy}}' "$img" | sort -t'|' -k1,1 -rn | head -1)
  if [ -z "$size" ] || [ -z "$layers" ] || [ -z "$dup" ] || [ -z "$big" ]; then
    echo "faltan datos de $img (size=$size layers=$layers dup=$dup)" >&2; exit 1
  fi
  {
    echo; echo "## $img"; echo
    echo "- Tamaño total sin comprimir: $((size / 1000000)) MB ($size bytes)"
    echo "- Capas: $layers"
    echo "- Capa más grande: $(( ${big%%|*} / 1000000 )) MB, creada por: \`$(echo "${big#*|}" | tr -d "\"\`" | cut -c1-160)\`"
    echo "- Archivos duplicados: $dup bytes"
    echo "- Shells: $shells"
    echo "- Binarios con setuid: $setuid"
  } >> "$OUT"
done
