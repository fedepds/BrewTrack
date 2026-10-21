# BrewTrack en Kubernetes (minikube)

`brewtrack.yaml` levanta `db` y `api`. `web-bluegreen.yaml` levanta la web en dos colores que comparten la misma API:

- `web-blue`: master (imagen `localhost/brewtrack-web:master`).
- `web-green`: la rama `feat/005-rebranding-tostado` (imagen `localhost/brewtrack-web:rebranding`).

El Service `web` manda el tráfico al color que diga su selector.

## Levantar

```sh
podman machine start
minikube start --driver=podman

# 1. Construir las imágenes y cargarlas en minikube (no las baja de ningún registro).
podman compose build
podman save localhost/brewtrack-api:0.1.0 -o /tmp/api.tar && minikube image load /tmp/api.tar
podman build -t localhost/brewtrack-web:master -f web/brewtrack-web.Containerfile web
git worktree add /tmp/green feat/005-rebranding-tostado
cp web/templates/default.conf.template /tmp/green/web/templates/   # la rama todavía no lee API_UPSTREAM
podman build -t localhost/brewtrack-web:rebranding -f /tmp/green/web/brewtrack-web.Containerfile /tmp/green/web
for t in master rebranding; do podman save localhost/brewtrack-web:$t -o /tmp/web-$t.tar && minikube image load /tmp/web-$t.tar; done

# 2. Crear el namespace y el Secret con las claves (sin escribirlas en ningún archivo versionado).
kubectl apply -f k8s/brewtrack.yaml -f k8s/web-bluegreen.yaml   # la primera vez db y api esperan el Secret
kubectl -n brewtrack create secret generic brewtrack \
  --from-literal=POSTGRES_PASSWORD="$(openssl rand -hex 24)" \
  --from-literal=JWT_SECRET="$(openssl rand -hex 32)"

# 3. Mirar cómo arrancan (Ctrl+C para salir).
kubectl -n brewtrack get pods -w

# 4. Abrir la web en http://localhost:8080
kubectl -n brewtrack port-forward svc/web 8080:8080
```

Primer admin:

```sh
kubectl -n brewtrack exec -it deploy/api -- python -m app.cli create-admin --email <correo> --name "<nombre>"
```

## Blue/green

```sh
# Ver los dos colores a la vez, sin tocar el Service
kubectl -n brewtrack port-forward deploy/web-blue 8081:8080
kubectl -n brewtrack port-forward deploy/web-green 8082:8080

# Qué color recibe el tráfico
kubectl -n brewtrack get svc web -o jsonpath='{.spec.selector.color}'

# Pasar el tráfico a green (y volver con "blue")
kubectl -n brewtrack patch svc web -p '{"spec":{"selector":{"color":"green"}}}'
```

El cambio es instantáneo y no reinicia nada; volver atrás es el mismo comando con el otro color. `kubectl apply` del YAML devuelve el tráfico a blue.

## Comandos útiles

| Para | Comando |
|---|---|
| Ver todo | `kubectl -n brewtrack get all` |
| Logs de la API | `kubectl -n brewtrack logs deploy/api` |
| Por qué no arranca un pod | `kubectl -n brewtrack describe pod <nombre>` |
| Aplicar cambios del YAML | `kubectl apply -f k8s/brewtrack.yaml` |
| Reiniciar la API tras cargar una imagen nueva | `kubectl -n brewtrack rollout restart deploy/api` |
| Borrar todo (incluida la base) | `kubectl delete namespace brewtrack` |
