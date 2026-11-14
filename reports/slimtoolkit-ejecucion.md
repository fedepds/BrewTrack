# Registro de ejecución — SlimToolkit

Fecha: 2026-11-14
Máquina: macOS (Apple Silicon), Colima con Docker Engine 29.9.3 (API 1.56, almacén de imágenes containerd).
Herramienta: `dslim/slim:1.40.11`, la última versión publicada (2024-02-02). Solo existe para amd64, así que en arm64 corre emulada.
Resultado: `reports/image-analysis.md`.

## 1. Primer intento: Slim contra el Docker de Colima

```sh
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock dslim/slim:1.40.11 \
  --check-version=false --report=off xray --changes none localhost/brewtrack-api:0.1.0
```

Falla:

```
API error (400): client version 1.24 is too old. Minimum supported API version is 1.40
```

Slim habla con Docker usando la API 1.24, y Docker 29 ya no la acepta.

## 2. Segundo intento: forzar una API más nueva

```sh
docker run --rm --platform linux/amd64 -v /var/run/docker.sock:/var/run/docker.sock \
  dslim/slim:1.40.11 --check-version=false --crt-api-version=1.44 --report=off \
  xray --changes none localhost/brewtrack-api:0.1.0
```

También probé `--crt-api-version` con 1.40, 1.41 y 1.43. Todas fallan igual:

```
dockerutil.SaveImage: dclient.ExportImage() error = API error (500):
invalid repository name (84b934ff…), cannot specify 64-byte hexadecimal strings
```

Slim exporta la imagen por su ID sin el prefijo `sha256:`. El almacén containerd de Docker 29 rechaza esa forma. `docker info` lo confirma: `driver-type io.containerd.snapshotter.v1`.

## 3. Solución: Docker 27 temporal (`dind`) con el almacén clásico

Levanto un Docker 27 dentro de un contenedor. Usa el almacén clásico (`overlay2`) y no toca las imágenes de Colima.

```sh
docker run -d --privileged --name slim-dind -e DOCKER_TLS_CERTDIR= docker:27.5.1-dind
docker exec slim-dind docker info --format '{{.ServerVersion}} {{.Driver}}'   # 27.5.1 overlay2
```

Copio las tres imágenes de Colima al Docker 27:

```sh
docker save localhost/brewtrack-api:0.1.0      | docker exec -i slim-dind docker load
docker save localhost/brewtrack-web:rebranding | docker exec -i slim-dind docker load
docker save localhost/brewtrack-db:0.1.0       | docker exec -i slim-dind docker load
```

## 4. `slim xray` contra el Docker 27

Slim comparte la red del contenedor `dind` y se conecta por `DOCKER_HOST`. Con `--host=tcp://…` falla con `docker.connect.error`, así que hay que usar la variable de entorno.

```sh
for img in brewtrack-api:0.1.0 brewtrack-web:rebranding brewtrack-db:0.1.0; do
  docker run --rm --platform linux/amd64 --network container:slim-dind \
    -e DOCKER_HOST=tcp://127.0.0.1:2375 dslim/slim:1.40.11 \
    --check-version=false xray --changes none --top-changes-max 8 localhost/$img \
    > ${img%%:*}.log 2>&1
done
```

Las tres terminan con código 0. Del log salen `layers.count`, la instrucción de cada capa (`change.instruction`), los duplicados (`image.stats.duplicates`), los shells (`image.shells`) y los binarios con setuid (`image.special_perms`).

`--report=/out/x.json` no dejó el JSON en el volumen montado, así que trabajé con el log.

## 5. Tamaños

Con este daemon, `xray` informa `size.bytes='0'`. Saco los tamaños del mismo Docker 27:

```sh
docker exec slim-dind docker image inspect localhost/brewtrack-api:0.1.0 \
  --format 'size={{.Size}} layers={{len .RootFS.Layers}}'
docker exec slim-dind docker history --no-trunc --format '{{.Size}}\t{{.CreatedBy}}' \
  localhost/brewtrack-api:0.1.0
```

(lo mismo con `web` y `db`)

## 6. Detalle de las capas grandes

Las ejecuto contra las imágenes de Colima, sin Slim:

```sh
# dependencias de Python por tamaño
docker run --rm --entrypoint sh localhost/brewtrack-api:0.1.0 -c \
  'cd /usr/local/lib/python3.13/site-packages && du -sm * | sort -rn | head -10'

# contenido de la app Flutter
docker run --rm --entrypoint sh localhost/brewtrack-web:rebranding -c \
  'cd /usr/share/nginx/html && du -sh * | sort -rh; du -sh canvaskit/* | sort -rh | head'

# versiones reales de las bases (para proponer etiquetas fijas)
docker run --rm --entrypoint python localhost/brewtrack-api:0.1.0 -c 'import sys; print(sys.version)'
docker run --rm --entrypoint sh localhost/brewtrack-api:0.1.0 -c 'cat /etc/debian_version'
docker run --rm --entrypoint nginx localhost/brewtrack-web:rebranding -v
docker run --rm --entrypoint postgres localhost/brewtrack-db:0.1.0 --version
docker run --rm --entrypoint sh ghcr.io/cirruslabs/flutter:stable -c 'flutter --version | head -1'
```

## 7. Limpieza

```sh
docker rm -f slim-dind
```

La imagen `docker:27.5.1-dind` queda descargada para la próxima vez.

## 8. Repetirlo con el script (spec 007)

`scripts/slim-analysis.sh` hace los pasos 3 a 7 y escribe el informe:

```sh
scripts/slim-analysis.sh image-analysis.md \
  localhost/brewtrack-db:0.1.0 localhost/brewtrack-api:0.1.0 localhost/brewtrack-web:rebranding
```

- Levanta `slim-dind-<BUILD_NUMBER o PID>` sin publicar puertos, copia cada imagen, corre `xray` y lee tamaño, capas, capa más grande, duplicados, shells y setuid.
- Sale con error si Slim falla o falta un dato de alguna imagen. Un `trap` borra el Docker temporal con éxito o con fallo (`docker ps -a --filter name=slim-dind` no debe listar nada).
- Las imágenes deben existir en el Docker local (`docker compose build` o el paso "Build imágenes" de Jenkins).

## 9. En Jenkins

La etapa "SlimToolkit imágenes" corre el mismo script entre "Trivy imágenes" y "Deploy minikube" y archiva `image-analysis.md`. Si falla, no hay deploy. El Docker temporal usa `--privileged`; el agente `security` lo revisa. Jenkins monta el socket del Docker de Colima, así que el contenedor `slim-dind-<build>` aparece junto a los demás y se borra al terminar.
