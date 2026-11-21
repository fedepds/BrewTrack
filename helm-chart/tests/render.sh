#!/usr/bin/env bash
# Comprueba lo que renderiza la chart. Uso: bash helm-chart/tests/render.sh
# Sale con código distinto de 0 si algún caso falla.
set -u
CHART="$(cd "$(dirname "$0")/.." && pwd)"
fails=0

pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
check() { # check <descripción> <salida> <patrón grep -E>
  if grep -Eq -- "$3" <<<"$2"; then pass "$1"; else fail "$1"; fi
}
check_not() {
  if grep -Eq -- "$3" <<<"$2"; then fail "$1"; else pass "$1"; fi
}
count() { # count <descripción> <salida> <patrón> <veces>
  if [ "$(grep -Ec -- "$3" <<<"$2")" -eq "$4" ]; then pass "$1"; else fail "$1"; fi
}

# --- #5: helm install levanta db, api y web ---
if helm lint "$CHART" >/dev/null 2>&1; then pass "helm lint"; else fail "helm lint"; fi

out="$(helm template rel "$CHART" -n ns 2>&1)"
check "StatefulSet rel-db" "$out" "kind: StatefulSet"
check "volumeClaimTemplates en db" "$out" "volumeClaimTemplates:"
count "Deployments api y web" "$out" "^kind: Deployment$" 2
count "Services db, api y web" "$out" "^kind: Service$" 3
check "nombre rel-db" "$out" "name: rel-db$"
check "nombre rel-api" "$out" "name: rel-api$"
check "nombre rel-web" "$out" "name: rel-web$"
check "Secret rel-secrets" "$out" "name: rel-secrets$"
check "DATABASE_URL con el Service db del release" "$out" 'postgresql\+psycopg://brewtrack:\$\(POSTGRES_PASSWORD\)@rel-db:5432/brewtrack'
check "API_UPSTREAM con nombre completo" "$out" 'http://rel-api\.ns\.svc\.cluster\.local:8000'
check "uid 70 para db" "$out" "runAsUser: 70$"
check "uid 1000 para api" "$out" "runAsUser: 1000$"
check "uid 101 para web" "$out" "runAsUser: 101$"
count "runAsNonRoot en los 3 pods" "$out" "runAsNonRoot: true" 3
count "raíz de solo lectura en los 3 contenedores" "$out" "readOnlyRootFilesystem: true" 3
count "readiness en los 3" "$out" "readinessProbe:" 3

# Las claves se generan al instalar: ningún archivo versionado de la chart las trae.
check_not "sin claves en archivos de la chart" "$(cat "$CHART"/values*.yaml "$CHART"/Chart.yaml 2>/dev/null)" "(PASSWORD|SECRET)"
jwt="$(sed -n 's/^ *JWT_SECRET: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' <<<"$out" | head -1)"
if [ -n "$jwt" ] && [ "$(printf %s "$jwt" | base64 -d | wc -c)" -ge 32 ]; then pass "JWT_SECRET de 32 caracteres o más"; else fail "JWT_SECRET de 32 caracteres o más"; fi

# --- #7: el Secret dura lo que la instalación, y existingSecret ---
check "Secret con resource-policy keep" "$out" 'helm\.sh/resource-policy: keep'
count "Secret y 5 referencias a rel-secrets" "$out" "name: rel-secrets$" 6
ext="$(helm template rel "$CHART" -n ns --set existingSecret=mio 2>&1)"
check_not "existingSecret no renderiza Secret" "$ext" "^kind: Secret$"
count "las 5 referencias leen el Secret indicado" "$ext" "name: mio$" 5
check_not "existingSecret no deja rastro de rel-secrets" "$ext" "rel-secrets"
count "SEED_ADMIN_* opcionales desde el Secret" "$ext" "key: SEED_ADMIN_(EMAIL|PASSWORD)$" 2
count "SEED_ADMIN_* marcados optional" "$ext" "optional: true$" 2

if [ "$fails" -eq 0 ]; then echo "todo ok"; else echo "$fails fallos"; fi
exit "$fails"
