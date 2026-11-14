# 007 — Imágenes con versiones fijas y análisis con SlimToolkit

Estado: aprobada
Fecha: 2026-11-14

## Contexto y objetivo

El usuario debe cumplir los requisitos de una entrega académica sobre contenedores:

- un Dockerfile por componente (backend, frontend y servicios auxiliares);
- imágenes con versiones específicas, nunca `latest`;
- procesos sin root;
- imágenes pequeñas gracias a multi-stage builds;
- calidad validada con Trivy (vulnerabilidades) y SlimToolkit (tamaño y capas);
- un reporte breve, `reports/image-analysis.md`, con el tamaño total de cada imagen, su número de capas y las optimizaciones posibles.

Estado al 2026-11-14 (ver `reports/image-analysis.md` y `reports/slimtoolkit-ejecucion.md`):

| Requisito | api | web | db |
|---|---|---|---|
| Un Containerfile | sí | sí | sí |
| Versión fija | parcial (`python:3.13-slim`) | no (`flutter:stable`, `nginx:alpine`) | parcial (`postgres:17-alpine`) |
| Sin root | sí (uid 1000) | sí (uid 101) | sí (uid 70) |
| Multi-stage | sí | sí | no: no compila nada |
| Trivy | sí, en Jenkins | sí, en Jenkins | sí, en Jenkins |
| SlimToolkit | a mano | a mano | a mano |

El `Jenkinsfile` también usa imágenes flotantes: `postgres:17-alpine`, `python:3.13-slim`, `ghcr.io/cirruslabs/flutter:stable`, `semgrep/semgrep` y `aquasec/trivy`. Es el hallazgo 10 que dejó pendiente la spec 004.

Las versiones que corren hoy son Python 3.13.18 sobre Debian 13.7 (trixie), Flutter 3.44.0, nginx 1.31.8 sobre Alpine 3.24 y PostgreSQL 17.11 sobre Alpine 3.24.

SlimToolkit 1.40.11, la última versión publicada, no funciona contra el Docker 29 de Colima. Funciona contra un Docker 27 temporal al que se copian las imágenes (D-1).

Objetivo: que las tres imágenes y el pipeline cumplan los requisitos de la entrega sin que el taller note ningún cambio. La misma URL, el mismo login y los mismos datos.

## Historias de usuario

- HU-1. Como `admin`, quiero que cada build use las mismas versiones de las imágenes base, para que una reconstrucción no traiga cambios que nadie pidió.
- HU-2. Como `admin`, quiero que Jenkins analice el tamaño y las capas de cada imagen en cada build, para ver si una imagen crece sin motivo.
- HU-3. Como `admin`, quiero un reporte versionado con el tamaño, las capas y las optimizaciones posibles de cada imagen, para entregarlo y para decidir qué mejorar.
- HU-4. Como `admin`, quiero seguir entrando por http://localhost:8081 después del cambio, sin aprender nada nuevo.

## Requisitos funcionales

### Versiones fijas

Ver D-2 y D-3.

- RF-1. Cada `FROM` de `api/brewtrack-api.Containerfile`, `web/brewtrack-web.Containerfile` y `db/brewtrack-db.Containerfile` usa una etiqueta con versión mayor, menor y de parche (por ejemplo `1.31.8`). No usa `latest`, `stable`, una versión parcial (`3.13`, `17`) ni falta de etiqueta.
- RF-2. Cada imagen sigue siendo la misma imagen de la constitución, con una etiqueta más precisa: `python` en variante `slim`, `nginx` en variante `alpine`, `postgres` en variante `alpine` y `ghcr.io/cirruslabs/flutter`.
- RF-3. Las versiones fijadas no son menores que las que corren hoy (ver Contexto). El developer anota en `dev-notes.md` qué etiqueta eligió para cada imagen y cómo comprobó que existe.
- RF-4. Todas las imágenes que usa el `Jenkinsfile` llevan versión mayor, menor y de parche, incluidas Semgrep, Trivy, `docker:27.5.1-dind` y `dslim/slim:1.40.11`.
- RF-5. Las imágenes con que Jenkins corre los tests (Postgres, Python y Flutter) usan la misma etiqueta que el `FROM` del Containerfile correspondiente.
- RF-6. Las imágenes de terceros en `k8s/` (`grafana/grafana:12.4.13` y `prometheus/prometheus:v3.15.1`) ya cumplen y no cambian.
- RF-7. Las etiquetas no llevan digest (`@sha256:…`). Ver "Fuera de alcance".

### Sin root, multi-stage y Trivy

- RF-8. Las tres imágenes siguen corriendo sin root, con los mismos usuarios: `app` (uid 1000) en `api`, `nginx` (uid 101) en `web` y `postgres` (uid 70) en `db`.
- RF-9. `api` y `web` siguen con dos etapas: una de compilación y una final que solo copia el resultado.
- RF-10. `db` sigue con una sola etapa, como excepción documentada, porque no compila nada (D-4). El reporte de RF-15 explica el motivo.
- RF-11. Trivy sigue pasando sobre las tres imágenes con las mismas reglas de hoy: severidad HIGH y CRITICAL, sin vulnerabilidades que ya tengan parche, y la misma excepción de `gosu` en `db`.
- RF-12. El developer puede quitar los pasos `apt-get upgrade` y `apk upgrade` solo si Trivy sigue pasando sin ellos. Anota en `dev-notes.md` qué hizo y por qué.

### Análisis con SlimToolkit en Jenkins

Ver D-3 y D-5.

- RF-13. Jenkins tiene una etapa nueva, después de "Trivy imágenes" y antes de "Deploy minikube", que analiza las tres imágenes con `slim xray` contra un Docker 27 temporal, como en `reports/slimtoolkit-ejecucion.md` (D-1).
- RF-14. La etapa borra el Docker 27 temporal al terminar, tanto si sale bien como si falla. Ese Docker no publica ningún puerto en el host, así que la tabla de puertos de `AGENTS.md` no cambia.
- RF-15. Cada build guarda como artefacto de Jenkins un archivo `image-analysis.md` con una sección por imagen. Cada sección trae:
  - el nombre y la etiqueta de la imagen;
  - el tamaño total sin comprimir;
  - el número de capas;
  - el tamaño de la capa más grande y la instrucción que la creó;
  - lo que señala Slim: tamaño de archivos duplicados, shells y binarios con setuid.
- RF-16. Si Slim falla o el archivo sale sin los datos de RF-15 para alguna imagen, la etapa falla y el build no llega a "Deploy minikube" (D-5). El informe del agente `security` revisa el uso de `--privileged` del Docker temporal (D-5).

### Reporte de la entrega

- RF-17. `reports/image-analysis.md` queda en el repositorio (hoy `reports/` no está versionado) y se actualiza con las imágenes de esta spec. Para cada imagen trae:
  - la etiqueta de cada imagen base;
  - el tamaño total y el número de capas;
  - las optimizaciones posibles, con el ahorro estimado en MB;
  - el motivo de que `db` no tenga dos etapas.
- RF-18. El reporte trae la tabla "Estado frente a los requisitos" con "sí" en todas las celdas, salvo multi-stage en `db`, que muestra la excepción de D-4.
- RF-19. `reports/slimtoolkit-ejecucion.md` queda en el repositorio y explica cómo repetir el análisis a mano y en Jenkins.

### El taller no nota el cambio

- RF-20. Solo `web` publica un puerto al host, el 8081, como dice la tabla de `AGENTS.md`.
- RF-21. La API responde en `/api/v1/health`, la SPA carga y el login funciona como hoy.

## Criterios de aceptación

CA-1 a CA-5 son revisiones de archivos. CA-6 a CA-10 se prueban sobre las imágenes construidas. CA-11 a CA-13 se prueban en Jenkins. CA-14 a CA-16 se prueban sobre el stack levantado con `docker compose up --build -d`.

- CA-1. Dado el código de la entrega, cuando QA ejecuta `grep -hE '^FROM' api/*.Containerfile web/*.Containerfile db/*.Containerfile | grep -vE ':[^ @]*[0-9]+\.[0-9]+\.[0-9]+'`, entonces no sale ninguna línea.
- CA-2. Dado el código de la entrega, cuando QA ejecuta `grep -nE 'latest|:stable|nginx:alpine|python:3\.13-slim|postgres:17-alpine' Jenkinsfile api/*.Containerfile web/*.Containerfile db/*.Containerfile`, entonces no sale ninguna línea. Cuando QA lista todas las imágenes del `Jenkinsfile` (las de `docker.image(...)`, `image '...'` y `docker run`), entonces cada una tiene versión mayor, menor y de parche.
- CA-3. Dado el código de la entrega, cuando QA compara la etiqueta de Postgres, Python y Flutter en el `Jenkinsfile` con la del `FROM` de cada Containerfile, entonces son iguales.
- CA-4. Dado el código de la entrega, cuando QA ejecuta `grep -c '^FROM' <archivo>`, entonces sale 2 para `api/brewtrack-api.Containerfile` y para `web/brewtrack-web.Containerfile`, y 1 para `db/brewtrack-db.Containerfile` (D-4).
- CA-5. Dado el código de la entrega, cuando QA ejecuta `git ls-files reports/`, entonces salen `reports/image-analysis.md` y `reports/slimtoolkit-ejecucion.md`.
- CA-6. Dadas las tres imágenes construidas, cuando QA ejecuta `docker image inspect --format '{{.Config.User}}' <imagen>`, entonces sale `app` en `api`, `nginx` en `web` y `postgres` en `db`.
- CA-7. Dadas las tres imágenes construidas, cuando QA ejecuta `docker run --rm --entrypoint id <imagen> -u`, entonces sale 1000 en `api`, 101 en `web` y 70 en `db`.
- CA-8. Dadas las tres imágenes construidas, cuando QA ejecuta `trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed --quiet <imagen>` (con `--skip-files usr/local/bin/gosu` en `db`), entonces las tres terminan con código 0.
- CA-9. Dada la imagen `api` construida, cuando QA ejecuta `docker run --rm --entrypoint python <imagen> -c 'import sys; print(sys.version)'`, entonces la versión no es menor que 3.13.18. Del mismo modo, `nginx -v` en `web` no da menos de 1.31.8 y `postgres --version` en `db` no da menos de 17.11.
- CA-10. Dado el código de la entrega, cuando QA lee `reports/image-analysis.md`, entonces encuentra para cada imagen la etiqueta de su base, el tamaño total, el número de capas y al menos una optimización posible con su ahorro en MB o la frase "sin optimización que compense" con el motivo. También encuentra el motivo de que `db` tenga una sola etapa y la tabla de RF-18.
- CA-11. Dado un push a `master`, cuando Jenkins termina el build, entonces la etapa de SlimToolkit aparece después de "Trivy imágenes" y antes de "Deploy minikube", y el build guarda el artefacto `image-analysis.md` con tres secciones, una por imagen, cada una con los datos de RF-15.
- CA-12. Dado un build que acaba de terminar, bien o con fallo en la etapa de SlimToolkit, cuando QA ejecuta `docker ps -a --filter name=slim-dind` (o el nombre que use la etapa), entonces no sale ningún contenedor.
- CA-13. Dado un build en el que Slim no puede analizar una imagen (por ejemplo, una etiqueta que no existe en el Docker temporal), cuando corre la etapa, entonces la etapa falla y "Deploy minikube" no corre.
- CA-14. Dado el stack sano, cuando QA ejecuta `docker compose ps`, entonces solo `web` publica un puerto, el 8081 del host.
- CA-15. Dado el stack sano, cuando QA pide `GET http://localhost:8081/api/v1/health`, entonces recibe 200. Cuando pide `http://localhost:8081/lotes`, entonces recibe 200 con `index.html`.
- CA-16. Dado el stack sano y un admin creado, cuando QA entra en http://localhost:8081 con sus credenciales, entonces ve la lista de lotes. Sin token, `GET http://localhost:8081/api/v1/green-lots` devuelve 401 con el cuerpo `{"error": {"code", "message"}}`.
- CA-17. Dado el código de la entrega, cuando se ejecutan `cd api && pytest`, `cd web && flutter analyze` y `cd web && flutter test`, entonces pasan sin cambios en lo que comprueban.

## Chequeo de constitución

- **Alcance:** aplica. La spec no añade funciones ni toca curvas, empaque, venta, recetas, cata ni multi-empresa. Las etiquetas exactas de las imágenes base y la etapa nueva de Jenkins siguen la constitución enmendada (D-2 y D-3).
- **Stock calculado:** no aplica. No cambia ningún cálculo ni dato.
- **Permisos en la API:** no aplica. No hay endpoints nuevos y la API sigue imponiendo los permisos (CA-16).
- **Formato de error:** no aplica. No hay respuestas nuevas. CA-16 comprueba que el formato sigue igual.
- **Migraciones:** no aplica. No cambia el esquema.
- **Secretos:** aplica. La etapa de SlimToolkit no lee `.env` ni pasa variables de entorno de la app a Slim ni al Docker temporal. El artefacto de RF-15 no trae valores de variables de entorno de las imágenes.

## Fuera de alcance

- Digest en las etiquetas (`@sha256:…`). Una etiqueta con versión de parche cumple el requisito de la entrega. Un digest impide recibir parches de seguridad que el proveedor publica bajo la misma etiqueta y obliga a cambiarlo a mano en cada reconstrucción.
- Las dos optimizaciones que propone el reporte: borrar los `*.symbols` de canvaskit en `web` (unos 5 MB) y cambiar `uvicorn[standard]` por `uvicorn` con `uvloop` y `httptools` en `api` (unos 10 MB). La entrega pide listar las optimizaciones posibles, no aplicarlas. Juntas ahorran unos 15 MB de 656 MB y cada una necesita sus propias pruebas. Pueden ir en una spec aparte.
- Quitar motores de render de Flutter, cambiar a una base distroless o compilar PostgreSQL propio.
- Las etiquetas de las imágenes propias (`localhost/brewtrack-*`). Hoy no coinciden: `compose.yaml` usa `brewtrack-web:0.1.0`, Jenkins construye `brewtrack-web:rebranding` y `k8s/web-bluegreen.yaml` usa `master` y `rebranding` (D-6).
- Cambiar Colima o pasar a Docker Desktop para que Slim funcione sin el Docker temporal (D-1).
- Una tarea que actualice las versiones fijadas de forma automática.

## Decisiones

- D-1. **SlimToolkit contra un Docker 27 temporal.** Slim 1.40.11 no exporta imágenes del almacén containerd de Docker 29 (Colima). El análisis corre contra un `docker:27.5.1-dind` al que se copian las imágenes con `docker save | docker load`, como en `reports/slimtoolkit-ejecucion.md`. No se cambia Colima ni se pasa a Docker Desktop. Lo decidió el usuario el 2026-11-14.
- D-2. **Etiqueta exacta de la misma imagen** (resuelve P-1). Una etiqueta más precisa de la misma imagen y variante (por ejemplo `nginx:1.31.8-alpine`) respeta la constitución. La constitución dice ahora que las imágenes base llevan etiqueta de versión exacta. Lo decidió el usuario el 2026-11-14.
- D-3. **Jenkins local entra en el alcance** (resuelve P-2). La constitución saca CI/CD de "Fuera" y pone en "Dentro" Jenkins local con tests, Semgrep, Trivy, SlimToolkit y deploy a minikube. TLS y backups automáticos siguen fuera. RF-4, RF-5 y RF-13 a RF-16 quedan en esta spec. Lo decidió el usuario el 2026-11-14.
- D-4. **`db` con una sola etapa** (resuelve P-3). `db` no compila nada, y una segunda etapa copiaría la imagen entera sin ahorrar nada. Queda como excepción documentada en el reporte (RF-10, RF-18). Lo decidió el usuario el 2026-11-14.
- D-5. **Slim bloquea el deploy** (resuelve P-4). Si Slim falla, falla el build y no hay deploy (RF-16, CA-13). Se acepta el Docker temporal con `--privileged`, y el agente `security` lo revisa en su informe. Lo decidió el usuario el 2026-11-14.
- D-6. **Etiquetas de las imágenes propias, en otra spec** (resuelve P-5). Las etiquetas `localhost/brewtrack-*` no cambian aquí, porque el despliegue blue-green de `k8s/` depende de ellas. Lo decidió el usuario el 2026-11-14.

## Preguntas abiertas

Ninguna. P-1 a P-5 de la versión 0.1 pasan a "Decisiones" (D-2 a D-6).

## Historial

| Fecha | Versión | Cambio |
|---|---|---|
| 2026-11-14 | 0.1 | Borrador a partir de los requisitos de la entrega académica sobre contenedores y del hallazgo 10 de la spec 004. Recoge D-1 (Slim contra un Docker 27 temporal). Quedan abiertas P-1 a P-5. |
| 2026-11-14 | 1.1 | El usuario acepta las cinco recomendaciones ("acepto"). P-1 a P-5 pasan a "Decisiones" (D-2 a D-6). Se enmienda la constitución: las imágenes base llevan etiqueta de versión exacta (D-2) y Jenkins local entra en el alcance (D-3). Los RF y CA que dependían de P-1 a P-4 dejan de ser condicionales. RF-16 añade la revisión de `--privileged` por `security`. |
| 2026-11-14 | 1.1 | El usuario aprueba la spec. |
