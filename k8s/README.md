# BrewTrack en Kubernetes (minikube)

`brewtrack.yaml` levanta `db` y `api`. `web-bluegreen.yaml` levanta la web en dos colores que comparten la misma API:

- `web-blue`: master (imagen `localhost/brewtrack-web:master`).
- `web-green`: la rama `feat/005-rebranding-tostado` (imagen `localhost/brewtrack-web:rebranding`).

El Service `web` manda el tráfico al color que diga su selector.

## Levantar

Usa Colima con runtime `docker`; minikube corre dentro de Colima.

```sh
colima start
minikube start --driver=docker

# 1. Construir las imágenes y cargarlas en minikube (no las baja de ningún registro).
docker compose build
docker build -t localhost/brewtrack-web:master -f web/brewtrack-web.Containerfile web
git worktree prune   # borra el registro de un /tmp/green anterior que ya no existe
git worktree add /tmp/green feat/005-rebranding-tostado
cp web/templates/default.conf.template /tmp/green/web/templates/   # la rama todavía no lee API_UPSTREAM
docker build -t localhost/brewtrack-web:rebranding -f /tmp/green/web/brewtrack-web.Containerfile /tmp/green/web
for i in api:0.1.0 web:master web:rebranding; do minikube image load localhost/brewtrack-$i; done

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

## Prohibir `latest` con Kyverno

`kyverno-disallow-latest.yaml` rechaza todo Pod, Deployment, StatefulSet o Job cuya imagen use `latest` o no lleve etiqueta. Necesita Kyverno 1.13 o posterior.

```sh
kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.19.2/install.yaml
kubectl -n kyverno wait --for=condition=Available deploy --all --timeout=300s
kubectl apply -f k8s/kyverno-disallow-latest.yaml

# Comprobar: los dos comandos fallan
kubectl run prueba --image=nginx:latest
kubectl run prueba --image=nginx
```

La política no acepta una imagen sin etiqueta, pero sí deja pasar `registro:5000/img`, porque toma el `:` del puerto como etiqueta. Si algún día usas un registro con puerto, exige un digest (`@sha256:`).

## Detectar shells con Falco

Falco vigila lo que pasa dentro de los contenedores y avisa, pero no bloquea. Solo se distribuye como chart de Helm (`brew install helm`).

```sh
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco --version 9.2.1 -n falco --create-namespace \
  --set driver.kind=modern_ebpf --set tty=true --wait

# Ver los avisos en vivo
kubectl -n falco logs ds/falco -c falco -f
```

Un `kubectl exec -it <pod> -- sh` deja una línea así, con pod, namespace, imagen y comando:

```
Notice A shell was spawned in a container with an attached terminal | ... k8s_pod_name=<pod> k8s_ns_name=<namespace>
```

## Bloquear `kubectl exec` con Kyverno

`kyverno-deny-exec.yaml` rechaza todo `kubectl exec` en el namespace `brewtrack`. Solo deja pasar `python -m app.cli`, para que el comando del primer admin siga funcionando. Bloquea también a cluster-admin, así que en minikube te afecta a ti.

```sh
kubectl apply -f k8s/kyverno-deny-exec.yaml

# Comprobar: el primero falla, el segundo pasa
kubectl -n brewtrack exec deploy/api -- sh -c 'echo dentro'
kubectl -n brewtrack exec deploy/api -- python -m app.cli --help

# Quitarla para depurar
kubectl delete -f k8s/kyverno-deny-exec.yaml
```

## Comandos útiles

| Para | Comando |
|---|---|
| Ver todo | `kubectl -n brewtrack get all` |
| Logs de la API | `kubectl -n brewtrack logs deploy/api` |
| Por qué no arranca un pod | `kubectl -n brewtrack describe pod <nombre>` |
| Aplicar cambios del YAML | `kubectl apply -f k8s/brewtrack.yaml` |
| Reiniciar la API tras cargar una imagen nueva | `kubectl -n brewtrack rollout restart deploy/api` |
| Borrar todo (incluida la base) | `kubectl delete namespace brewtrack` |
