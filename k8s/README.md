# BrewTrack en Minikube

Despliega en el namespace `brewtrack`. Compose sigue siendo el destino principal.
Corre todo desde la raíz del repositorio. Los valores de `.env` nunca salen por pantalla.

Archivos: `k8s/namespace.yaml` (Namespace) y `k8s/brewtrack.yaml` (volumen, y Deployment y Service de `db`, `api` y `web`) y `k8s/monitoring.yaml` (Deployment y Service de `prometheus` y `grafana`).

## 1. Construir las imágenes

```sh
podman build -f api/brewtrack-api.Containerfile -t localhost/brewtrack-api:0.2.0 api
podman build -f web/brewtrack-web.Containerfile -t localhost/brewtrack-web:0.1.1 web
```

## 2. Cargarlas en Minikube

```sh
minikube image load localhost/brewtrack-api:0.2.0
minikube image load localhost/brewtrack-web:0.1.1
```

## 3. Crear el namespace

```sh
kubectl apply -f k8s/namespace.yaml
```

## 4. Crear el Secret desde `.env`

```sh
kubectl create secret generic brewtrack-secrets -n brewtrack \
  --from-env-file=<(grep -E '^(POSTGRES_PASSWORD|JWT_SECRET|GRAFANA_ADMIN_PASSWORD)=' .env)
```

## 5. Aplicar los manifiestos

```sh
kubectl apply -f k8s/brewtrack.yaml
```

## 6. Esperar a que estén listos

```sh
kubectl rollout status deploy/db deploy/api deploy/web -n brewtrack --timeout=180s
```

`api` puede reiniciarse un par de veces mientras `db` arranca. Es normal.

## 7. Crear el primer admin

```sh
kubectl exec -it -n brewtrack deploy/api -- python -m app.cli create-admin --email <correo> --name "<nombre>"
```

## 8. Abrir la web

```sh
kubectl port-forward -n brewtrack svc/web 8081:80
```

Abre http://localhost:8081.

## 9. Actualizar una imagen

Cambia la etiqueta en `compose.yaml` y en `k8s/brewtrack.yaml`, y luego:

```sh
podman build -f web/brewtrack-web.Containerfile -t localhost/brewtrack-web:<nueva> web
minikube image load localhost/brewtrack-web:<nueva>
kubectl apply -f k8s/brewtrack.yaml
```

## 10. Quitar la aplicación y borrar los datos

Quitar la aplicación conserva el volumen `brewtrack-pgdata`, el Secret y el namespace:

```sh
kubectl delete deploy,svc --all -n brewtrack
```

Para volver a desplegar, repite desde el paso 5.

Borrar los datos es un paso aparte. Esto destruye la base:

```sh
kubectl delete pvc brewtrack-pgdata -n brewtrack
```

Para dejar el clúster sin nada de BrewTrack, borra también el namespace (incluye Secret y volumen):

```sh
kubectl delete namespace brewtrack
```

## Monitoreo con Prometheus y Grafana

La configuración vive en `monitoring/` y es la misma que usa compose. Los Pods de `prometheus` y `grafana` guardan sus datos en un `emptyDir`: si borras el Pod, pierdes el historial de métricas. El panel, las alertas y la contraseña vuelven solos.

`.env` necesita `GRAFANA_ADMIN_PASSWORD`. El paso 4 la suma al Secret. Si ya creaste el Secret sin ella, bórralo con `kubectl delete secret brewtrack-secrets -n brewtrack` y crea el Secret de nuevo.

Crea las ConfigMaps (después del paso 3):

```sh
kubectl create configmap prometheus-config -n brewtrack --from-file=monitoring/prometheus.yml
kubectl create configmap grafana-datasources -n brewtrack --from-file=monitoring/grafana/provisioning/datasources
kubectl create configmap grafana-dashboards -n brewtrack --from-file=monitoring/grafana/provisioning/dashboards
kubectl create configmap grafana-alerting -n brewtrack --from-file=monitoring/grafana/provisioning/alerting
```

Aplica y espera:

```sh
kubectl apply -f k8s/monitoring.yaml
kubectl rollout status deploy/prometheus deploy/grafana -n brewtrack --timeout=240s
```

Abre Grafana:

```sh
kubectl port-forward -n brewtrack svc/grafana 3001:3000
```

Entra en http://127.0.0.1:3001 con el usuario `admin` y la contraseña de `GRAFANA_ADMIN_PASSWORD`. Si compose ocupa el 3001, usa otro puerto local, por ejemplo `3002:3000`.

Tras cambiar un umbral en `monitoring/grafana/provisioning/alerting/rules.yaml`, actualiza la ConfigMap y reinicia `grafana`:

```sh
kubectl create configmap grafana-alerting -n brewtrack --from-file=monitoring/grafana/provisioning/alerting \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart deploy/grafana -n brewtrack
```

La imagen `api` pasó a `0.2.0` (suma `/metrics`). Constrúyela y cárgala de nuevo con los pasos 1 y 2.

### Cambiar la contraseña de admin

Grafana guarda la contraseña de admin en su base la primera vez que arranca. Cambiar `GRAFANA_ADMIN_PASSWORD` después no la cambia. Con el Pod en marcha, usa la CLI de Grafana (la contraseña nueva entra por variable de entorno, no la escribas en el comando):

```sh
kubectl exec -n brewtrack deploy/grafana -- sh -c 'grafana cli admin reset-admin-password "$GF_SECURITY_ADMIN_PASSWORD"'
```

Antes, actualiza el Secret con el valor nuevo y reinicia `grafana`. En Minikube, borrar el Pod también basta: el `emptyDir` se vacía y Grafana arranca con la contraseña del Secret.

## Variable de nginx

La imagen `web` lee el host de la API de `API_HOST`. Sin la variable usa `api` (compose). Los manifiestos la fijan en `api.brewtrack.svc.cluster.local`, porque el `resolver` de nginx no usa los dominios de búsqueda de Kubernetes.
