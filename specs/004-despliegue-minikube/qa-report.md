# 004 — Informe de QA

Veredicto: APROBADO

## Criterios de aceptación

| CA | Resultado | Evidencia |
|---|---|---|
| 1 | Cumple | `curl localhost:8080/api/v1/health` -> `{"status":"ok"}` 200 |
| 2 | Cumple | `podman compose restart api`; health 200 por `web`, sin reiniciar `web` |
| 3 | Cumple | `podman inspect` de `web`: sin `API_HOST` en el entorno |
| 4 | Cumple | `kubectl apply --dry-run=client -f k8s/namespace.yaml -f k8s/brewtrack.yaml`: rc 0, 8 objetos `created (dry run)` |
| 5 | Cumple | grep en `k8s/`: sin `kind: Secret`, sin valores; la contraseña solo entra por `secretKeyRef` y `$(POSTGRES_PASSWORD)` |
| 6 | Cumple | `manifest.yaml` no existe; `git ls-files manifest.yaml` vacío |
| 7 | Cumple | Namespace `brewtrack`; todos los objetos con `namespace: brewtrack`; `API_HOST=api.brewtrack.svc.cluster.local`; sin `hostPort`; Services `ClusterIP` |
| 8 | Cumple | `rollout status` de `db`, `api`, `web` en 19 s. `api` se reinició 2 veces mientras `db` arrancaba (RF-11) |
| 9 | Cumple | Eventos: solo `Pulled ... already present`; sin `Pulling` |
| 10 | Cumple con desvío | `port-forward` en 18080 (8080 lo ocupa compose): health 200 |
| 11 | Cumple | `GET /api/v1/green-lots` sin token: 401 `{"error":{"code":"unauthorized","message":...}}` |
| 12 | Cumple | `create-admin` por `kubectl exec`, login OK, `?limit=5&offset=0` -> `limit` 5, `offset` 0, `total` 20 |
| 13 | Cumple | `GET /lotes` -> 200 `text/html`, `index.html` |
| 14 | Cumple | Borrado del Pod `api`: health 200 por `web`; Pod `web` sin reinicios |
| 15 | Cumple | Borrado del Pod `db`: el admin inicia sesión con el Pod nuevo (ver defecto 1) |
| 16 | Cumple | `kubectl delete deploy,svc --all -n brewtrack`: PVC `brewtrack-pgdata` sigue `Bound`. Al reaplicar, el admin seguía |
| 17 | Cumple | `kubectl delete namespace brewtrack`: `NotFound`; sin `port-forward` vivos. Mismos recursos en `default` que antes (ver nota) |
| 18 | Cumple | `k8s/README.md` trae los 10 pasos en orden, copiables. El Secret entra con `--from-env-file=<(grep ...)`, sin mostrar valores |
| 19 | Cumple (developer) | Pytest 96, flutter test 15, analyze limpio, según el developer. No lo repetí |

Antes de probar: `kubectl get ns brewtrack` dio `NotFound` (RF-9). `minikube image ls` lista `brewtrack-web:0.1.1` y `brewtrack-api:0.1.0`. No ejecuté `minikube image load`.

## Constitución

| Regla | Resultado | Evidencia |
|---|---|---|
| Alcance | Cumple | Solo despliegue y variable de nginx; sin funciones nuevas |
| Stock calculado | No aplica | Sin cambios de cálculo |
| Permisos en la API | Cumple | 401 a través de `web` en el clúster (CA-11); sin endpoints nuevos |
| Formato de error | Cumple | CA-11 |
| Migraciones | Cumple | Sin cambios de esquema; `api` migró sobre base vacía en el clúster |
| Secretos | Cumple | Sin Secret ni valores en `k8s/`; QA usó valores inventados y no leyó `.env` |
| Imagen `api` sin root y health con la imagen sola | No evaluado | La spec no toca esa imagen |
| Idioma de comentarios y revisión de redacción | Pendiente de revisión humana | Aprueba el PR la persona usuaria |

## Defectos

1. Baja. Justo después de borrar el Pod de `db`, el primer login falló una vez (504 en la primera corrida, timeout de 20 s en la segunda) y los siguientes funcionaron. El `readinessProbe` de `api` mira `/health`, que no toca la base, y `api` mantiene conexiones viejas en el pool. Para reproducir: con CA-12 hecho, `kubectl delete pod -n brewtrack -l app=db`, esperar `rollout status` y pedir un login. No incumple la spec (CA-15 pide que el admin pueda iniciar sesión con el Pod nuevo, y pudo). Decisión del product-owner si quiere `pool_pre_ping` en otra spec.
2. Baja. El README no dice que `create-admin` pide la contraseña por teclado y exige `-it`. El comando ya lleva `-it`; sin terminal falla con `EOFError`. Solo informativo.

## Notas

- Desvío menor de CA-10: `port-forward` en 18080 en vez de 8080.
- En `default` hay un Pod ajeno, `brewtrack2-db-1-pod`, y un PVC `brewtrack2-pgdata`, de un `kube play` de unos 25 minutos. No lo toqué. Al terminar solo cambió su estado (`Error` a `CrashLoopBackOff`) y la edad. El resto de la foto es igual.
- Los valores del Secret de prueba salieron en mi terminal por el trace del shell. Eran inventados y el namespace ya no existe.

## Criterios sin prueba

Ninguno, salvo CA-19 (no repetido) y la revisión humana de redacción.
