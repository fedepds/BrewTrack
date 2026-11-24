# Políticas de Kyverno

Kyverno revisa cada pod (y cada Deployment, StatefulSet, Job, etc.) cuando llega al API server y rechaza los que incumplen una política. Las políticas están en `kyverno/policies/` y los casos de prueba en `kyverno/tests/`.

## Políticas

| # | Política | Qué exige | Por qué |
|---|---|---|---|
| 01 | `brewtrack-disallow-latest-tag` | Imagen con etiqueta (o digest) y distinta de `latest` | `latest` cambia sin aviso: dos pods de la misma versión pueden correr código distinto y no hay forma de volver atrás. |
| 02 | `brewtrack-require-requests-limits` | `requests` y `limits` de CPU y memoria en cada contenedor | Sin límites, un pod puede tomar toda la memoria del nodo y tirar a los demás. Sin requests, el scheduler no sabe dónde ubicarlo. |
| 03 | `brewtrack-require-run-as-non-root` | `runAsNonRoot: true` (del pod o del contenedor) y ningún `runAsUser: 0` | Un proceso root en el contenedor está a un fallo del kernel de ser root en el nodo. |
| 04 | `brewtrack-disallow-privilege-escalation` | `allowPrivilegeEscalation: false` en cada contenedor y ninguno `privileged` | La política que eligió el equipo. Un contenedor privilegiado ve los dispositivos del nodo; la escalada deja que un binario setuid gane permisos. Es parte del perfil *restricted* de Pod Security Standards. |

Detalles comunes:

- **Formato:** `ValidatingPolicy` (`policies.kyverno.io/v1`) con expresiones CEL, el formato que usa hoy la librería oficial de Kyverno. Pide Kyverno 1.19.1 o más; `scripts/kyverno-up.sh` instala la chart 3.9.2 (Kyverno v1.19.2).
- **Acción:** `Deny`. El API server rechaza el recurso y `kubectl` o Helm muestran el mensaje de la política.
- **Alcance:** todo el clúster menos `kube-system`, `kube-public`, `kube-node-lease`, `kyverno`, `ingress-nginx` y `falco`. Falco necesita correr privilegiado para leer las llamadas al sistema del nodo.
- **Recursos:** pods y todo lo que crea pods. Un Deployment que incumple se rechaza al crearlo, así que `helm install` falla con el mensaje en vez de dejar un Deployment sin pods.
- **Auditoría en segundo plano:** activada. Los recursos que ya existían antes de la política aparecen en los `PolicyReport` del namespace.

## Qué pasa con lo que ya existe

| Recursos | ¿Cumplen? |
|---|---|
| Chart `helm-chart/` (`values.yaml`, dev y prod), incluido el pod de `helm test` | Sí, las cuatro. `helm-chart/tests/render.sh` comprueba límites, `seccompProfile`, `drop: ALL` y sin `latest`. |
| `k8s/prometheus.yaml`, `k8s/grafana.yaml` | Sí, las cuatro |
| `k8s/brewtrack.yaml`, `k8s/web-bluegreen.yaml` (YAML viejos) | No: les faltan los límites (02). Se reemplazaron por la chart. |

## Cómo correrlo

```sh
bash scripts/kyverno-up.sh          # instala Kyverno y aplica las políticas
bash scripts/kyverno-validate.sh    # aplica cada caso de kyverno/tests/ y escribe reports/kyverno-validation.log
```

`kyverno-validate.sh` crea los recursos de verdad, no en modo prueba. Lo que Kyverno admite (`pod-ok`) se borra al final. Sale con código 0 solo si cada caso dio lo esperado.

| Caso | Incumple | Esperado |
|---|---|---|
| `pod-ok.yaml` | nada | admitido |
| `pod-latest.yaml` | 01: `busybox:latest` | rechazado |
| `pod-sin-etiqueta.yaml` | 01: `busybox` sin etiqueta | rechazado |
| `pod-sin-limites.yaml` | 02: sin `resources` | rechazado |
| `pod-root.yaml` | 03: `runAsUser: 0`, `runAsNonRoot: false` | rechazado |
| `pod-privilegiado.yaml` | 04: `privileged: true`, `allowPrivilegeEscalation: true` | rechazado |
| `deployment-malo.yaml` | 01 y 02, en un Deployment | rechazado |

Para probar a mano un caso y ver el mensaje:

```sh
kubectl apply -f kyverno/tests/pod-root.yaml
# Error from server: ... denied the request: brewtrack-require-run-as-non-root: runAsUser 0 es root y no está permitido.
```

## Cambiar una política

Editar el YAML en `kyverno/policies/`, aplicarlo con `kubectl apply -f kyverno/policies/` y volver a correr `scripts/kyverno-validate.sh`. Si una herramienta nueva necesita privilegios, se agrega su namespace a la lista `NotIn` de las cuatro políticas.
