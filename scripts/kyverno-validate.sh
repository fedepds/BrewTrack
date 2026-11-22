#!/usr/bin/env bash
# Prueba cada política de Kyverno con los manifiestos de kyverno/tests/ y deja la evidencia en
# reports/kyverno-validation.log. Crea los recursos de verdad (no dry-run): lo que Kyverno admite se borra al final.
#
# Esperado: pod-ok.yaml se admite; todos los demás se rechazan con el mensaje de su política.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

NS=brewtrack
LOG=reports/kyverno-validation.log
mkdir -p reports
kubectl get namespace "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS" >/dev/null

exec > >(tee "$LOG") 2>&1

section() { printf '\n===== %s\n' "$*"; }

section "Kyverno: validación de políticas — $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "Clúster: $(kubectl config current-context)"
echo "Kyverno: $(kubectl -n kyverno get deploy kyverno-admission-controller -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo 'no encontrado')"

section "Políticas instaladas"
kubectl get validatingpolicies -o custom-columns='NOMBRE:.metadata.name,ACCIÓN:.spec.validationActions,SEVERIDAD:.metadata.annotations.policies\.kyverno\.io/severity'

pass=0; fail=0
for f in kyverno/tests/*.yaml; do
  name=$(basename "$f" .yaml)
  expect=rechazado; [ "$name" = pod-ok ] && expect=admitido
  section "$name — $(sed -n '1s/^# //p' "$f")"
  echo "\$ kubectl apply -f $f"
  if out=$(kubectl apply -f "$f" 2>&1); then got=admitido; else got=rechazado; fi
  echo "$out"
  if [ "$got" = "$expect" ]; then
    echo "RESULTADO: $got (esperado: $expect) -> OK"; pass=$((pass + 1))
  else
    echo "RESULTADO: $got (esperado: $expect) -> FALLA"; fail=$((fail + 1))
  fi
  [ "$got" = admitido ] && kubectl delete -f "$f" --wait=false >/dev/null 2>&1
done

section "Los pods de BrewTrack cumplen las políticas (siguen corriendo)"
kubectl -n "$NS" get pods -o wide

section "PolicyReports del namespace $NS (resultado de la auditoría en segundo plano)"
kubectl -n "$NS" get policyreports -o custom-columns='RECURSO:.scope.kind,NOMBRE:.scope.name,PASS:.summary.pass,FAIL:.summary.fail' 2>/dev/null \
  || echo "(sin PolicyReports todavía)"

section "Resumen: $pass OK, $fail fallas"
[ "$fail" -eq 0 ]
