# Chart de Helm de BrewTrack

Instala `db`, `api` y `web` en Kubernetes con un solo comando. La chart genera las claves (`POSTGRES_PASSWORD` y `JWT_SECRET`) al instalar: no hay que crearlas ni escribirlas en ningún archivo.

## Antes de empezar

Necesitas `kubectl`, `helm` y un clúster. Estos pasos usan minikube:

```sh
minikube start --driver=docker
```

La chart usa por defecto las imágenes `localhost/brewtrack-db`, `localhost/brewtrack-api` y `localhost/brewtrack-web` con la etiqueta `0.1.0` y no las baja de ningún registro. Constrúyelas con `docker compose` y cárgalas en minikube, desde la raíz del repo:

```sh
docker compose build
for i in db api web; do
  docker save localhost/brewtrack-$i:0.1.0 -o /tmp/$i.tar && minikube image load /tmp/$i.tar
done
minikube image ls | grep brewtrack    # deben salir las tres
```

## Instalar

Cada entorno tiene su archivo de valores. Elige uno con `-f`. Usa un namespace por instalación: así dev y prod conviven en el mismo clúster.

| Entorno | Comando |
|---|---|
| Por defecto | `helm install brewtrack ./helm-chart -n brewtrack --create-namespace` |
| Desarrollo | `helm install brewtrack ./helm-chart -n brewtrack-dev --create-namespace -f helm-chart/values-dev.yaml` |
| Producción | `helm install brewtrack ./helm-chart -n brewtrack-prod --create-namespace -f helm-chart/values-prod.yaml` |

Corre los comandos desde la raíz del repo. Al terminar, Helm imprime cómo abrir la web, leer una clave y crear el primer admin.

Diferencias entre entornos:

| | Por defecto | `values-dev.yaml` | `values-prod.yaml` |
|---|---|---|---|
| Réplicas de `web` | 1 | 1 | 2 |
| Recursos | sin límites | bajos | más altos |
| Lotes de ejemplo | sí | sí | no |
| Service de `web` | `ClusterIP` | `NodePort` | `ClusterIP` |
| Ingress | no | no | sí, clase `nginx`, host `brewtrack.local` |
| Volumen de la base | 1 Gi | 1 Gi | 10 Gi |

Los recursos de prod caben en un nodo de 4 CPU y 8 GiB que comparte otras cargas. Súbelos si tu clúster tiene más.

## Esperar y verificar

```sh
kubectl -n brewtrack-dev get pods -w     # Ctrl+C cuando los tres estén Running y 1/1
helm test brewtrack -n brewtrack-dev      # debe terminar con "Phase: Succeeded"
```

La API se reinicia una o dos veces al arrancar mientras espera a la base. Es normal.

`helm test` pide `/api/v1/health` a la web. Si responde 200, la web sirve, el proxy de nginx llega a la API y la API llega a la base.

## Abrir la web

**Por defecto (port-forward):**

```sh
kubectl -n brewtrack port-forward svc/brewtrack-web 8090:8080
```

Abre http://localhost:8090. Usa cualquier puerto local libre; 8081 lo usa `docker compose`.

**Desarrollo (NodePort):**

```sh
minikube service brewtrack-web -n brewtrack-dev --url
```

Abre la URL que imprime. Con el driver `docker` en macOS, el comando queda abierto mientras uses la web.

**Producción (Ingress):** sigue la sección siguiente.

## Ingress en minikube

1. Activa el controlador de Ingress y espera a que esté listo. Instala prod después: si el controlador no está listo, `helm install` falla con `failed calling webhook "validate.nginx.ingress.kubernetes.io"`.

   ```sh
   minikube addons enable ingress
   kubectl -n ingress-nginx wait --for=condition=ready pod -l app.kubernetes.io/component=controller --timeout=180s
   ```

2. Haz que `brewtrack.local` llegue al controlador. Depende del driver de minikube (`minikube profile list` lo muestra):

   - **Driver `docker` en macOS o Windows:** la IP de minikube no se alcanza desde tu máquina. Agrega esta línea a `/etc/hosts`:

     ```
     127.0.0.1 brewtrack.local
     ```

     y deja corriendo en otra terminal (pide tu contraseña):

     ```sh
     minikube tunnel
     ```

   - **Linux, o un driver con VM (`hyperkit`, `qemu`, `virtualbox`):** agrega a `/etc/hosts` la IP de minikube:

     ```sh
     echo "$(minikube ip) brewtrack.local" | sudo tee -a /etc/hosts
     ```

3. Abre http://brewtrack.local. Debe salir el login de BrewTrack.

Para probar sin tocar `/etc/hosts`:

```sh
kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 8099:80
curl -H 'Host: brewtrack.local' http://localhost:8099/                 # HTML con <title>BrewTrack</title>
curl -H 'Host: brewtrack.local' http://localhost:8099/api/v1/health    # {"status":"ok"}
```

## Primer admin

Sin un Secret propio no hay admin al arrancar. Créalo con la CLI (pide la contraseña, de 8 caracteres o más):

```sh
kubectl -n brewtrack-prod exec -it deploy/brewtrack-api -- python -m app.cli create-admin --email <correo> --name "<nombre>"
```

## Valores

Cambia cualquiera con `--set` o con tu propio archivo `-f`.

| Valor | Por defecto | Para qué |
|---|---|---|
| `existingSecret` | `""` | Nombre de un Secret propio con `POSTGRES_PASSWORD`, `JWT_SECRET` (32 caracteres o más) y, si quieres, `SEED_ADMIN_EMAIL` y `SEED_ADMIN_PASSWORD`. Vacío: la chart crea `<release>-secrets`. |
| `db.image.repository`, `.tag`, `.pullPolicy` | `localhost/brewtrack-db`, `0.1.0`, `IfNotPresent` | Imagen de la base. |
| `db.service.type`, `.port` | `ClusterIP`, `5432` | Service de la base. |
| `db.resources` | `{}` | Requests y limits de CPU y memoria. |
| `db.persistence.size` | `1Gi` | Tamaño del volumen. |
| `db.persistence.storageClass` | `""` | Clase de almacenamiento. Vacío: la del clúster. |
| `api.image.*` | `localhost/brewtrack-api`, `0.1.0`, `IfNotPresent` | Imagen de la API. |
| `api.replicas` | `1` | Sin efecto: la API corre migraciones al arrancar y queda en 1 réplica. |
| `api.service.type`, `.port` | `ClusterIP`, `8000` | Service de la API. |
| `api.resources` | `{}` | Requests y limits. |
| `api.config.timezone` | `America/Argentina/Buenos_Aires` | `TIMEZONE` de la API. |
| `api.config.seedDemoLots` | `"true"` | Crea lotes de ejemplo si la base está vacía. |
| `web.image.*` | `localhost/brewtrack-web`, `0.1.0`, `IfNotPresent` | Imagen de la web. |
| `web.replicas` | `1` | Réplicas de la web. |
| `web.service.type`, `.port` | `ClusterIP`, `8080` | `ClusterIP` o `NodePort`. |
| `web.resources` | `{}` | Requests y limits. |
| `ingress.enabled` | `false` | Crea el Ingress de la web. |
| `ingress.className` | `""` | Clase de Ingress. Vacío: la del clúster. |
| `ingress.host` | `brewtrack.local` | Nombre con el que se abre la web. |
| `ingress.annotations` | `{}` | Anotaciones del Ingress. |

## Actualizar y borrar

```sh
helm upgrade brewtrack ./helm-chart -n brewtrack-prod -f helm-chart/values-prod.yaml
helm uninstall brewtrack -n brewtrack-prod
```

`helm upgrade` conserva las claves. `helm uninstall` deja el volumen de la base y el Secret: una instalación nueva con el mismo nombre abre los datos viejos. Para borrarlo todo:

```sh
kubectl delete namespace brewtrack-prod
```

## Probar la chart sin clúster

```sh
bash helm-chart/tests/render.sh
```

Corre `helm lint` y `helm template` con cada archivo de valores y sale con un código distinto de 0 si algo falla.
