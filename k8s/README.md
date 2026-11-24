# BrewTrack en Kubernetes (minikube)

`brewtrack.yaml` levanta `db` y `api`. `web-bluegreen.yaml` levanta la web en dos colores que comparten la misma API:

- `web-blue`: la rama `UI_vieja`, la UI anterior (imagen `localhost/brewtrack-web:0.1.0`).
- `web-green`: el árbol actual con el rebranding (imagen `localhost/brewtrack-web:0.2.0`).

El Service `web` manda el tráfico al color que diga su selector.

Para instalar con un solo comando y elegir entorno (dev o prod), usa la chart de Helm: ver [`helm-chart/README.md`](../helm-chart/README.md).

## Con Helm (recomendado)

La chart `helm-chart/` reemplaza a los YAML de esta carpeta para `db`, `api` y `web`: genera las claves, pone límites de CPU y memoria en cada pod y trae un Ingress opcional. Valores, entornos y verificación: [`helm-chart/README.md`](../helm-chart/README.md).

Los recursos llevan el nombre del release (`brewtrack-db`, `brewtrack-api`, `brewtrack-web`), así que no chocan con los de los YAML. Igual conviene borrar los viejos para no tener dos bases corriendo.

```sh
kubectl delete -f k8s/brewtrack.yaml -f k8s/web-bluegreen.yaml --ignore-not-found   # solo si se aplicaron a mano

helm lint ./helm-chart -f helm-chart/values-dev.yaml
helm install brewtrack ./helm-chart -n brewtrack --create-namespace -f helm-chart/values-dev.yaml
helm test brewtrack -n brewtrack                                   # GET a /api/v1/health a través de web
kubectl -n brewtrack port-forward svc/brewtrack-web 8081:8080     # http://localhost:8081
```

| Para | Comando |
|---|---|
| Ver qué genera la chart | `helm template brewtrack ./helm-chart -f helm-chart/values-dev.yaml` |
| Producción | `-f helm-chart/values-prod.yaml` |
| Borrar | `helm uninstall brewtrack -n brewtrack && kubectl delete namespace brewtrack` |

Jenkins despliega con esta misma chart en el namespace `brewtrack`, pero baja las imágenes del registro local (`--set api.image.repository=brewtrack-registry:5000/brewtrack-api`, etc.). Ver `docs/ci/jenkins.md`.

## Levantar con los YAML

```sh
colima start
minikube start --driver=docker

# 1. Construir las imágenes y cargarlas en minikube (no las baja de ningún registro).
docker compose build
for i in db api; do docker save localhost/brewtrack-$i:0.1.0 -o /tmp/$i.tar && minikube image load /tmp/$i.tar; done
git worktree add /tmp/blue UI_vieja
docker build -t localhost/brewtrack-web:0.1.0 -f /tmp/blue/web/brewtrack-web.Containerfile /tmp/blue/web
docker build -t localhost/brewtrack-web:0.2.0 -f web/brewtrack-web.Containerfile web
for t in 0.1.0 0.2.0; do docker save localhost/brewtrack-web:$t -o /tmp/web-$t.tar && minikube image load /tmp/web-$t.tar; done

# 2. Crear el namespace y el Secret con las claves (sin escribirlas en ningún archivo versionado).
kubectl apply -f k8s/brewtrack.yaml -f k8s/web-bluegreen.yaml   # la primera vez db y api esperan el Secret
kubectl -n brewtrack create secret generic brewtrack \
  --from-literal=POSTGRES_PASSWORD="$(openssl rand -hex 24)" \
  --from-literal=JWT_SECRET="$(openssl rand -hex 32)"

# 3. Mirar cómo arrancan (Ctrl+C para salir).
kubectl -n brewtrack get pods -w

# 4. Abrir la web en http://localhost:8081
kubectl -n brewtrack port-forward svc/web 8081:8080
```

Primer admin:

```sh
kubectl -n brewtrack exec -it deploy/api -- python -m app.cli create-admin --email <correo> --name "<nombre>"
```

## Monitoreo (Prometheus + Grafana)

Prometheus lee `/metrics` de cada pod de la API (métricas HTTP y de negocio) y la CPU y memoria de cada pod (cAdvisor del kubelet). Grafana muestra el dashboard de `grafana/dashboard.json`.

```sh
scripts/monitoring-up.sh                                    # Prometheus, Grafana y el dashboard; también lo actualiza
kubectl -n brewtrack port-forward svc/grafana 3000:3000     # http://localhost:3000, usuario admin
kubectl -n brewtrack get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d   # clave de admin
kubectl -n brewtrack port-forward svc/prometheus 9090:9090  # http://localhost:9090/targets: api y kubernetes-cadvisor en UP

# Tráfico para llenar los paneles (5 minutos, ~5 pedidos/s)
kubectl -n brewtrack port-forward svc/brewtrack-web 8081:8080 &
ADMIN_EMAIL=<correo> ADMIN_PASSWORD=<clave> scripts/load.sh
```

| Panel | Consulta (resumida) |
|---|---|
| Pedidos por segundo | `sum(rate(http_requests_total{job="api", handler!="/metrics"}[1m]))` |
| Latencia promedio | `rate(http_request_duration_seconds_sum[1m]) / rate(http_request_duration_seconds_count[1m])` |
| CPU por pod | `sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="brewtrack"}[1m]))` |
| Memoria por pod | `sum by (pod) (container_memory_working_set_bytes{namespace="brewtrack"})` |
| Stock de café verde | `brewtrack_green_stock_kg` |
| Merma (24 h) | `1 - increase(brewtrack_roast_out_kg_total[24h]) / increase(brewtrack_roast_green_in_kg_total[24h])` |

Para cambiar el dashboard: editarlo en Grafana, exportarlo (*Share → Export → Save to file*), guardarlo como `grafana/dashboard.json` y volver a correr `scripts/monitoring-up.sh`.

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
