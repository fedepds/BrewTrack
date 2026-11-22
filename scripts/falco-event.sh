#!/usr/bin/env bash
# Simula a un atacante que entró al contenedor de la API y busca credenciales, y guarda lo que Falco detecta
# en reports/falco-event.log. No abre ningún shell: kubectl exec corre find y grep directamente.
#
# Reglas que se disparan (reglas estables de Falco, prioridad WARNING):
#   - "Search Private Keys or Passwords": find buscando id_rsa y grep buscando "BEGIN RSA PRIVATE".
#   - "Find AWS Credentials": find buscando .aws/credentials.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

NS=brewtrack
LOG=reports/falco-event.log
RULES='Search Private Keys or Passwords|Find AWS Credentials'
mkdir -p reports

POD=$(kubectl -n "$NS" get pods -l app.kubernetes.io/component=api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
[ -n "$POD" ] || { echo "no hay pod de la API en $NS: instala la chart primero"; exit 1; }
kubectl -n falco get ds falco >/dev/null 2>&1 || { echo "Falco no está instalado: corre scripts/falco-up.sh"; exit 1; }

since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
exec > >(tee "$LOG") 2>&1

printf '===== Falco: evento de seguridad en tiempo de ejecución — %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
echo "Falco: $(kubectl -n falco get ds falco -o jsonpath='{.spec.template.spec.containers[0].image}')"
echo "Pod atacado: $NS/$POD"
cat <<'EOF'

Escenario: alguien consiguió ejecutar comandos dentro del contenedor de la API (por ejemplo, con una
dependencia vulnerable) y busca llaves SSH o credenciales de AWS para saltar a otros sistemas.
Es un paso típico de "acceso a credenciales" (MITRE ATT&CK T1552). La API nunca corre find ni grep,
así que cualquier búsqueda de ese tipo dentro de su contenedor es sospechosa.
EOF

printf '\n===== Acciones\n'
run() { echo "\$ $*"; "$@" 2>&1 | head -5; echo; }
run kubectl -n "$NS" exec "$POD" -c api -- find / -xdev -name id_rsa
run kubectl -n "$NS" exec "$POD" -c api -- grep -rl "BEGIN RSA PRIVATE" /etc /srv
run kubectl -n "$NS" exec "$POD" -c api -- find / -xdev -path "*/.aws/credentials"

# Falco tarda menos de un segundo; se deja margen.
sleep 5

printf '===== Alertas de Falco (JSON, una por línea)\n'
alerts=$(kubectl -n falco logs ds/falco -c falco --since-time="$since" 2>/dev/null | grep -E "\"rule\":\"($RULES)\"")
if [ -z "$alerts" ]; then
  echo "Falco no registró alertas. Revisa: kubectl -n falco logs ds/falco -c falco --since-time=$since"
  exit 1
fi
echo "$alerts"

printf '\n===== Resumen\n'
if command -v python3 >/dev/null 2>&1; then
  python3 - "$alerts" <<'PY'
import json, sys
for line in sys.argv[1].splitlines():
    a = json.loads(line)
    f = a.get("output_fields", {})
    pod = f.get("k8s.pod.name") or f.get("container.name") or "?"
    print(f"{a['time'][:19]}  {a['priority']:<8} {a['rule']}")
    print(f"    pod={pod}  usuario={f.get('user.name')}  uid={f.get('user.uid')}  comando={f.get('proc.cmdline')}")
PY
else
  echo "$alerts" | sed -E 's/.*"priority":"([^"]*)".*"rule":"([^"]*)".*/\1  \2/'
fi
echo
echo "Total: $(echo "$alerts" | wc -l | tr -d ' ') alertas"
