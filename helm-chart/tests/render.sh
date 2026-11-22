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
count "runAsNonRoot en los 3 pods y el de test" "$out" "runAsNonRoot: true" 4
count "raíz de solo lectura en los 3 contenedores y el de test" "$out" "readOnlyRootFilesystem: true" 4
count "readiness en los 3" "$out" "readinessProbe:" 3

# --- #6: valores configurables y ConfigMap ---
check "ConfigMap rel-config" "$out" "^kind: ConfigMap$"
check "TIMEZONE por defecto en el ConfigMap" "$out" 'TIMEZONE: "America/Argentina/Buenos_Aires"'
check "SEED_DEMO_LOTS por defecto en el ConfigMap" "$out" 'SEED_DEMO_LOTS: "true"'
check "API_UPSTREAM en el ConfigMap" "$out" 'API_UPSTREAM: "http://rel-api\.ns\.svc\.cluster\.local:8000"'
count "api y web leen el ConfigMap" "$out" "name: rel-config$" 3
check "hash del ConfigMap en el pod de api" "$out" "checksum/config: [0-9a-f]{64}"

set_out="$(helm template rel "$CHART" -n ns \
  --set api.image.repository=reg/api,api.image.tag=9.9,api.image.pullPolicy=Always \
  --set web.image.repository=reg/web,web.image.tag=8.8,db.image.repository=reg/db,db.image.tag=7.7 \
  --set web.replicas=4,api.replicas=5 \
  --set api.resources.limits.memory=777Mi,web.resources.requests.cpu=33m,db.resources.limits.memory=555Mi \
  --set api.service.port=9000,web.service.port=9080,db.service.port=6543 \
  --set web.service.type=NodePort,api.service.type=NodePort,db.service.type=NodePort \
  --set db.persistence.size=3Gi,db.persistence.storageClass=fast \
  --set api.config.timezone=UTC,api.config.seedDemoLots=false 2>&1)"
check "imagen api" "$set_out" 'image: "reg/api:9\.9"'
check "imagen web" "$set_out" 'image: "reg/web:8\.8"'
check "imagen db" "$set_out" 'image: "reg/db:7\.7"'
check "pullPolicy api" "$set_out" "imagePullPolicy: Always"
check "réplicas web" "$set_out" "replicas: 4$"
check_not "api ignora réplicas pedidas" "$set_out" "replicas: 5$"
check "comentario: api fija por las migraciones" "$(cat "$CHART/templates/api.yaml")" "replicas: 1.*migraciones|migraciones.*replicas"
check "recursos api" "$set_out" "memory: 777Mi"
check "recursos web" "$set_out" "cpu: 33m"
check "recursos db" "$set_out" "memory: 555Mi"
check "puerto api" "$set_out" "port: 9000$"
check "puerto web" "$set_out" "port: 9080$"
check "puerto db" "$set_out" "port: 6543$"
count "tipo de Service en los 3" "$set_out" "type: NodePort$" 3
check "DATABASE_URL sigue el puerto de db" "$set_out" "@rel-db:6543/brewtrack"
check "API_UPSTREAM sigue el puerto de api" "$set_out" "rel-api\.ns\.svc\.cluster\.local:9000"
check "tamaño del volumen" "$set_out" "storage: 3Gi"
check "storageClass" "$set_out" "storageClassName: fast"
check "TIMEZONE desde los valores" "$set_out" 'TIMEZONE: "UTC"'
check "SEED_DEMO_LOTS desde los valores" "$set_out" 'SEED_DEMO_LOTS: "false"'
h1="$(grep -Eo 'checksum/config: [0-9a-f]+' <<<"$out" | head -1)"
h2="$(grep -Eo 'checksum/config: [0-9a-f]+' <<<"$set_out" | head -1)"
if [ -n "$h1" ] && [ "$h1" != "$h2" ]; then pass "el hash cambia con la config"; else fail "el hash cambia con la config"; fi
check_not "sin storageClassName por defecto" "$out" "storageClassName"

other="$(helm template otro "$CHART" -n tienda 2>&1)"
check "API_UPSTREAM con otro release y namespace" "$other" 'API_UPSTREAM: "http://otro-api\.tienda\.svc\.cluster\.local:8000"'
# --- #8: liveness probes y pod de helm test ---
count "liveness en los 3" "$out" "livenessProbe:" 3
check "pod de test con hook" "$out" 'helm\.sh/hook: test'
check "el test pide /api/v1/health a través de web" "$out" 'http://rel-web:8080/api/v1/health'
check "NOTES.txt existe" "$(cat "$CHART"/templates/NOTES.txt 2>/dev/null)" "create-admin"

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

# --- #9: Ingress, values-dev y values-prod ---
for f in values.yaml values-dev.yaml values-prod.yaml; do
  if helm lint "$CHART" -f "$CHART/$f" >/dev/null 2>&1; then pass "helm lint -f $f"; else fail "helm lint -f $f"; fi
done
dev="$(helm template rel "$CHART" -n ns -f "$CHART/values-dev.yaml" 2>&1)"
prod="$(helm template rel "$CHART" -n ns -f "$CHART/values-prod.yaml" 2>&1)"
check_not "sin Ingress por defecto" "$out" "^kind: Ingress$"
check_not "sin Ingress en dev" "$dev" "^kind: Ingress$"
check "Ingress en prod" "$prod" "^kind: Ingress$"
check "Ingress con clase nginx en prod" "$prod" "ingressClassName: nginx$"
check "Ingress con host brewtrack.local en prod" "$prod" "host: \"?brewtrack\.local\"?$"
check "Ingress manda a rel-web" "$prod" "name: rel-web$"
ing="$(helm template rel "$CHART" -n ns --set ingress.enabled=true,ingress.host=cafe.test,ingress.className=otra \
  --set-string 'ingress.annotations.ejemplo\.io/a=b' 2>&1)"
check "Ingress con ingress.enabled=true" "$ing" "^kind: Ingress$"
check "host desde los valores" "$ing" "host: \"?cafe\.test\"?$"
check "clase desde los valores" "$ing" "ingressClassName: otra$"
check "anotaciones desde los valores" "$ing" 'ejemplo\.io/a: "?b"?$'
check_not "sin ingressClassName si la clase está vacía" "$(helm template rel "$CHART" --set ingress.enabled=true 2>&1)" "ingressClassName"
check "dev: 1 réplica de web" "$dev" "replicas: 1$"
check_not "dev: sin 2 réplicas" "$dev" "replicas: 2$"
check "prod: 2 réplicas de web" "$prod" "replicas: 2$"
check "dev: lotes de ejemplo" "$dev" 'SEED_DEMO_LOTS: "true"'
check "prod: sin lotes de ejemplo" "$prod" 'SEED_DEMO_LOTS: "false"'
check "dev: web NodePort" "$dev" "type: NodePort$"
check_not "prod: sin NodePort" "$prod" "type: NodePort$"
check "prod: volumen de 10Gi" "$prod" "storage: 10Gi"
count "dev: recursos en los 3, el pod de test y el volumen" "$dev" "^ *resources:$" 5
count "prod: recursos en los 3, el pod de test y el volumen" "$prod" "^ *resources:$" 5
dres="$(grep -A6 '^ *resources:$' <<<"$dev" | grep -E 'cpu|memory' | sort)"
pres="$(grep -A6 '^ *resources:$' <<<"$prod" | grep -E 'cpu|memory' | sort)"
if [ -n "$dres" ] && [ "$dres" != "$pres" ]; then pass "recursos distintos entre dev y prod"; else fail "recursos distintos entre dev y prod"; fi
check "NOTES: NodePort" "$(cat "$CHART/templates/NOTES.txt")" "NodePort"
check "NOTES: Ingress" "$(cat "$CHART/templates/NOTES.txt")" "ingress\.enabled"
check "README de la chart" "$(cat "$CHART/README.md" 2>/dev/null)" "values-prod\.yaml"

# --- Laboratorio 4: lo que exigen las políticas de Kyverno (kyverno/policies/) ---
for v in values.yaml values-dev.yaml values-prod.yaml; do
  o="$(helm template rel "$CHART" -n ns -f "$CHART/$v" 2>&1)"
  count "$v: limits en los 3 contenedores y el de test" "$o" "^ *limits:$" 4
  count "$v: requests en los 3 contenedores, el de test y el volumen" "$o" "^ *requests:$" 5
  cpu_lim="$(grep -A2 '^ *limits:$' <<<"$o" | grep -E '^ *cpu:')"
  check_not "$v: límites de CPU sin fracciones (Semgrep no-fractional-cpu-limits)" "$cpu_lim" 'm"?$'
  check_not "$v: ninguna imagen latest" "$o" 'image: "[^"]*:latest"'
done
count "seccomp RuntimeDefault en los 3 pods y el de test" "$out" "type: RuntimeDefault$" 4
count "sin token de ServiceAccount en los 3 pods y el de test" "$out" "automountServiceAccountToken: false$" 4
count "sin escalada de privilegios en los 3 contenedores y el de test" "$out" "allowPrivilegeEscalation: false$" 4
count "capabilities drop ALL en los 3 contenedores y el de test" "$out" 'drop: \["ALL"\]$' 4
check "web por defecto es la UI actual (0.2.0)" "$out" 'image: "localhost/brewtrack-web:0\.2\.0"'

if [ "$fails" -eq 0 ]; then echo "todo ok"; else echo "$fails fallos"; fi
exit "$fails"
