#!/usr/bin/env bash
# Corre Semgrep sobre todo el repo y escribe reports/semgrep-report.txt.
#   1. Prueba las reglas propias (semgrep/python-security.yaml) con sus casos de semgrep/python-security.py.
#   2. Escanea con las reglas de la comunidad (repo semgrep/semgrep-rules) y las propias.
# Devuelve el código de salida de semgrep (0 aunque haya hallazgos: el informe es para revisarlos).
#
# Requisitos: semgrep (pip install semgrep o brew install semgrep) y git.
# SEMGREP_RULES_DIR: carpeta con un clon de semgrep-rules (por defecto ~/semgrep-rules; se clona si falta).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

RULES=${SEMGREP_RULES_DIR:-$HOME/semgrep-rules}
OUT=reports/semgrep-report.txt
mkdir -p reports

if [ ! -d "$RULES/python" ]; then
  echo "clonando semgrep-rules en $RULES"
  git clone -q --depth 1 https://github.com/semgrep/semgrep-rules.git "$RULES" || exit 1
fi

{
  printf '===== Semgrep — %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "Semgrep $(semgrep --version)"
  echo "Reglas de la comunidad: semgrep-rules @ $(git -C "$RULES" rev-parse --short HEAD)"
  echo "Reglas propias: semgrep/python-security.yaml"

  printf '\n===== 1. Prueba de las reglas propias (semgrep --test)\n'
  semgrep --test semgrep/ --metrics=off 2>&1 | grep -E 'passed|failed|ruleid|expected'
} > "$OUT"

# Excluidos: dependencias y builds, y archivos que incumplen a propósito (casos de prueba de reglas y políticas).
EXCLUDES=(
  --exclude=.venv --exclude=.venv-ci --exclude=.pubcache --exclude=.dart_tool --exclude=web/build
  --exclude=.superpowers --exclude=.playwright-mcp --exclude=reports
  --exclude=semgrep/python-security.py --exclude=kyverno/tests
  --exclude=docs/security/scan_semgrep.txt
)

printf '\n===== 2. Escaneo del repo\n' >> "$OUT"
echo "\$ semgrep scan --config <reglas> --metrics=off ${EXCLUDES[*]} ." >> "$OUT"
semgrep scan --metrics=off --no-rewrite-rule-ids --disable-version-check \
  --config "$RULES/python" \
  --config "$RULES/dockerfile" \
  --config "$RULES/yaml" \
  --config "$RULES/generic/nginx" \
  --config "$RULES/generic/secrets" \
  --config semgrep/python-security.yaml \
  "${EXCLUDES[@]}" --text . 2>&1 | sed -e 's/\x1b\[[0-9;]*m//g' >> "$OUT"   # sin colores, legible en cualquier editor
rc=${PIPESTATUS[0]}
echo "informe: $OUT (código de salida de semgrep: $rc)"
exit "$rc"
