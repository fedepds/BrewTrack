#!/usr/bin/env bash
# Corre Snyk sobre las dependencias de la API y escribe reports/snyk-report.txt.
# Con IMAGES=1 también analiza las imágenes de compose (snyk container test) en reports/snyk-container-report.txt.
#
# Uso: scripts/snyk-scan.sh   (token: SNYK_TOKEN o, mejor, guardado una vez con "snyk auth"; ver ci/snyk-cli.sh)
# Sale con código 1 si hay alguna vulnerabilidad crítica, igual que el pipeline.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

OUT=reports/snyk-report.txt
mkdir -p reports
# shellcheck source=/dev/null
. ci/snyk-cli.sh || exit 1

# Snyk lee las versiones reales de un entorno instalado: se instala la API como en el Containerfile.
VENV=$(mktemp -d)/venv
# shellcheck source=/dev/null
python3 -m venv "$VENV" && . "$VENV/bin/activate"
pip install -q ./api
pip freeze --exclude-editable | grep -vi '^brewtrack-api' > api/requirements-snyk.txt

{
  printf '===== Snyk: dependencias de la API — %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "Snyk CLI $("$SNYK" --version)"
  echo "Archivo: api/requirements-snyk.txt ($(wc -l < api/requirements-snyk.txt | tr -d ' ') paquetes, generado con pip freeze tras pip install ./api)"
  echo
  echo "\$ snyk test --file=requirements-snyk.txt --package-manager=pip --severity-threshold=low"
} > "$OUT"

# Informe con todas las severidades; el corte por críticas se calcula aparte.
(cd api && "$SNYK" test --file=requirements-snyk.txt --package-manager=pip --command=python \
  --project-name=brewtrack-api --severity-threshold=low 2>&1) | tee -a "$OUT"

printf '\n===== Corte del pipeline: solo vulnerabilidades críticas\n' >> "$OUT"
(cd api && "$SNYK" test --file=requirements-snyk.txt --package-manager=pip --command=python \
  --project-name=brewtrack-api --severity-threshold=critical >/dev/null 2>&1)
crit=$?
case $crit in
  0) echo "Sin vulnerabilidades críticas: el pipeline sigue." ;;
  1) echo "Hay vulnerabilidades críticas: el pipeline se detiene." ;;
  *) echo "Snyk no pudo completar el análisis (código $crit)." ;;
esac | tee -a "$OUT"

if [ "${IMAGES:-0}" = 1 ]; then
  C=reports/snyk-container-report.txt
  : > "$C"
  for img in localhost/brewtrack-db:0.1.0 localhost/brewtrack-api:0.1.0 localhost/brewtrack-web:0.2.0; do
    echo "===== $img" | tee -a "$C"
    "$SNYK" container test "$img" --severity-threshold=high 2>&1 | tee -a "$C"
  done
fi

deactivate
exit "$crit"
