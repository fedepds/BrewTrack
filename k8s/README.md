# BrewTrack en Minikube

Despliega en el namespace `brewtrack`. Compose sigue siendo el destino principal.
Corre todo desde la raíz del repositorio. Los valores de `.env` nunca salen por pantalla.

Archivos: `k8s/namespace.yaml` (Namespace) y `k8s/brewtrack.yaml` (volumen, y Deployment y Service de `db`, `api` y `web`).

## 1. Construir las imágenes

```sh
podman build -f api/brewtrack-api.Containerfile -t localhost/brewtrack-api:0.1.0 api
podman build -f web/brewtrack-web.Containerfile -t localhost/brewtrack-web:0.1.1 web
```

## 2. Cargarlas en Minikube

```sh
minikube image load localhost/brewtrack-api:0.1.0
minikube image load localhost/brewtrack-web:0.1.1
```

## 3. Crear el namespace

```sh
kubectl apply -f k8s/namespace.yaml
```

## 4. Crear el Secret desde `.env`

```sh
kubectl create secret generic brewtrack-secrets -n brewtrack \
  --from-env-file=<(grep -E '^(POSTGRES_PASSWORD|JWT_SECRET)=' .env)
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
kubectl port-forward -n brewtrack svc/web 8080:80
```

Abre http://localhost:8080.

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

## Variable de nginx

La imagen `web` lee el host de la API de `API_HOST`. Sin la variable usa `api` (compose). Los manifiestos la fijan en `api.brewtrack.svc.cluster.local`, porque el `resolver` de nginx no usa los dominios de búsqueda de Kubernetes.
