#!/usr/bin/env bash
# Genera tráfico contra BrewTrack para llenar el dashboard de Grafana: lecturas, tuestes nuevos,
# algunos logins fallidos y algunos 404. Crea su propio lote de café verde (código LOAD-...).
#
# Uso:
#   kubectl -n brewtrack port-forward svc/brewtrack-web 8081:8080 &     # o usar el Ingress
#   ADMIN_EMAIL=admin@taller.uy ADMIN_PASSWORD=... scripts/load.sh
#
# Variables: BASE_URL (http://localhost:8081), DURATION en segundos (300), RPS aproximado (5).
set -euo pipefail
export LC_ALL=C   # awk con locale de coma decimal rompe sleep y el JSON

BASE_URL=${BASE_URL:-http://localhost:8081}
API="$BASE_URL/api/v1"
DURATION=${DURATION:-300}
RPS=${RPS:-5}
: "${ADMIN_EMAIL:?define ADMIN_EMAIL}"
: "${ADMIN_PASSWORD:?define ADMIN_PASSWORD}"

log() { printf '[load %s] %s\n' "$(date +%H:%M:%S)" "$*"; }
# Extrae un campo de nivel superior de un JSON chico sin depender de jq.
field() { sed -n "s/.*\"$1\":\"\\{0,1\\}\\([^\",}]*\\).*/\\1/p"; }

login() {
  curl -sf -X POST "$API/auth/login" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" | field access_token
}

TOKEN=$(login) || { log "no pude entrar con $ADMIN_EMAIL en $BASE_URL"; exit 1; }
AUTH=(-H "Authorization: Bearer $TOKEN")

new_lot() {
  local code body
  code="LOAD-$(date +%s)"
  body="{\"code\":\"$code\",\"origin_country\":\"Colombia\",\"variety\":\"Caturra\",\"process\":\"washed\",\"harvest_year\":2026,\"received_at\":\"$(date +%F)\",\"received_kg\":300}"
  curl -sf -X POST "$API/green-lots" "${AUTH[@]}" -H 'Content-Type: application/json' -d "$body" | field id
}

roast() {
  local lot=$1 green out level
  green=$(( RANDOM % 11 + 5 ))                                   # 5 a 15 kg verdes
  out=$(awk -v g="$green" -v r="$RANDOM" 'BEGIN{printf "%.3f", g * (0.80 + (r % 80) / 1000)}')  # merma 12–20 %
  level=$(printf 'light\nmedium\ndark' | sed -n "$(( RANDOM % 3 + 1 ))p")
  curl -s -o /dev/null -w '%{http_code}' -X POST "$API/roasts" "${AUTH[@]}" -H 'Content-Type: application/json' \
    -d "{\"lot_id\":\"$lot\",\"roasted_at\":\"$(date -u +%FT%TZ)\",\"green_in_kg\":$green,\"roasted_out_kg\":$out,\"duration_s\":$(( RANDOM % 300 + 540 )),\"drop_temp_c\":$(( RANDOM % 25 + 195 )).0,\"roast_level\":\"$level\"}"
}

get() { curl -s -o /dev/null -w '%{http_code}' "${AUTH[@]}" "$API$1"; }

LOT=$(new_lot)
log "lote $LOT creado (300 kg). Corriendo ${DURATION}s a ~${RPS} pedidos/s contra $BASE_URL"

end=$(( $(date +%s) + DURATION ))
n=0; roasts=0; errors=0
sleep_s=$(awk -v r="$RPS" 'BEGIN{printf "%.3f", 1 / r}')
while [ "$(date +%s)" -lt "$end" ]; do
  n=$(( n + 1 ))
  case $(( n % 20 )) in
    0)  code=$(roast "$LOT")
        if [ "$code" = 201 ]; then roasts=$(( roasts + 1 ))
        elif [ "$code" = 409 ]; then LOT=$(new_lot); log "lote sin stock, nuevo lote $LOT"
        else errors=$(( errors + 1 )); fi ;;
    7)  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/auth/login" -H 'Content-Type: application/json' \
          -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"incorrecta\"}") ;;        # login fallido (401)
    13) code=$(get "/roasts/00000000-0000-0000-0000-000000000000") ;;            # 404
    1|5|9|15) code=$(get "/green-lots?limit=20") ;;
    2|6|10|16) code=$(get "/roasts?limit=20") ;;
    3|11|17) code=$(get "/stats/summary") ;;
    *)  code=$(get "/green-lots/$LOT") ;;
  esac
  case $code in 5*) errors=$(( errors + 1 )) ;; esac
  # El token dura poco: se renueva cada 500 pedidos.
  if [ $(( n % 500 )) -eq 0 ]; then TOKEN=$(login); AUTH=(-H "Authorization: Bearer $TOKEN"); fi
  if [ $(( n % 100 )) -eq 0 ]; then log "$n pedidos, $roasts tuestes, $errors errores 5xx"; fi
  sleep "$sleep_s"
done
log "fin: $n pedidos, $roasts tuestes nuevos, $errors errores 5xx"
