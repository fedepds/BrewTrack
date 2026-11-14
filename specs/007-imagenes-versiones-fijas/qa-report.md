# Informe de QA — 007 Imágenes con versiones fijas y SlimToolkit

Fecha: 2026-11-14
Rama: `feat/007-imagenes-versiones-fijas`
Spec: 1.2 (aprobada). Seguridad: `security-report.md`, veredicto APROBADO.

## Veredicto: APROBADO

Todos los CA pasan con evidencia local. CA-11 y la parte de Jenkins de CA-12 y CA-13 no tienen prueba en un build real de Jenkins (ver "Criterios sin prueba"). La parte de login de CA-16 queda pendiente de revisión humana. No hay fallos que bloqueen.

## Criterios de aceptación

| CA | Resultado | Evidencia |
|---|---|---|
| CA-1 | Pasa | El filtro no devuelve líneas. Los `FROM`: `python:3.13.18-slim-trixie` (x2), `postgres:17.11-alpine3.24`, `flutter:3.44.0`, `nginx:1.31.8-alpine`. |
| CA-2 | Pasa | El `grep` no devuelve líneas. Imágenes del `Jenkinsfile`: `postgres:17.11-alpine3.24`, `python:3.13.18-slim-trixie`, `flutter:3.44.0`, `semgrep:1.184.0`, `trivy:0.76.2`. `docker:27.5.1-dind` y `dslim/slim:1.40.11` están en `scripts/slim-analysis.sh`. |
| CA-3 | Pasa | Postgres, Python y Flutter del `Jenkinsfile` coinciden con los `FROM`. |
| CA-4 | Pasa | `grep -c '^FROM'`: api 2, web 2, db 1. |
| CA-5 | Pasa | `git ls-files reports/` lista los dos archivos. |
| CA-6 | Pasa | `Config.User`: api `app`, web `nginx`, db `postgres`. |
| CA-7 | Pasa | `id -u`: api 1000, web 101, db 70. |
| CA-8 | Pasa | Trivy 0.76.2 por socket, `--exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed`: las tres salen 0 (db con `--skip-files usr/local/bin/gosu`). |
| CA-9 | Pasa | Python 3.13.18, nginx 1.31.8, PostgreSQL 17.11. |
| CA-10 | Pasa | `reports/image-analysis.md` trae base, tamaño, capas, optimizaciones con MB o "sin optimización que compense", motivo de `db` en una etapa (D-4) y la tabla de RF-18. Ver F-1 (baja). |
| CA-11 | Pendiente (sin prueba en Jenkins real) | `Jenkinsfile`: etapa "SlimToolkit imágenes" (línea 97) entre "Trivy imágenes" (83) y "Deploy minikube" (104). `archiveArtifacts artifacts: 'image-analysis.md'` en `post always`. El script en local genera las tres secciones con los datos de RF-15. |
| CA-12 | Pasa en local; sin prueba en Jenkins real | Tras el caso de éxito y el de fallo, `docker ps -a --filter name=slim-dind` sale vacío. |
| CA-13 | Pasa en local; sin prueba en Jenkins real | Con `localhost/nope:9.9.9` el script sale con código 1. `set -e` en el `sh` de la etapa hace fallar la etapa y el build, y "Deploy minikube" va después. |
| CA-14 | Pasa | `docker compose ps`: solo `web` publica puerto, `0.0.0.0:8081->8080`. |
| CA-15 | Pasa | `GET :8081/api/v1/health` 200; `GET :8081/lotes` 200 con `index.html`. |
| CA-16 | Parcial | Sin token, `GET /api/v1/green-lots` da 401 con `{"error":{"code":"unauthorized","message":...}}`. El login con admin queda pendiente de revisión humana: no hay credenciales disponibles sin leer `.env`. |
| CA-17 | Pasa | `pytest`: 115 passed. `flutter analyze`: No issues found. `flutter test`: 38 passed. |

## Constitución

| Regla | Resultado | Evidencia |
|---|---|---|
| Alcance | Pasa | El cambio toca imágenes, Jenkins, reportes y `AGENTS.md`. No añade funciones fuera de alcance. |
| Stock calculado | Pasa | Sin cambios en `models.py` ni migraciones (`pytest` verde). |
| Permisos en la API | Pasa | Sin endpoints nuevos. Sin token, 401. Las pruebas de roles de `pytest` pasan. |
| Formato de error | Pasa | El 401 devuelve `{"error": {"code", "message"}}`. |
| Migraciones | Pasa | Sin cambio de esquema. La API arrancó sana con `alembic upgrade head` en el contenedor. |
| Secretos | Pasa | No se leyó `.env`. `slim-analysis.sh` no pasa variables de la app. El artefacto trae tamaños y conteos, no variables de entorno. |
| API sin root y `/health` | Pasa | Usuario `app` (uid 1000); `/api/v1/health` 200 con el stack levantado. |
| Idioma de comentarios y prosa | Pendiente de revisión humana | Lo aprueba quien revise el PR. |

## Fallos

| ID | Severidad | Descripción | Reproducción |
|---|---|---|---|
| F-1 | Baja | `reports/image-analysis.md` dice que la capa más grande de `api` es de 103 MB (dependencias), pero su propia tabla lista una capa base de 110 MB, y el script mide 100 MB para la base Debian. Las cifras de capas mezclan MB y MiB. Afecta a CA-10 solo en precisión; no cambia ningún dato exigido. | `sh scripts/slim-analysis.sh out.md localhost/brewtrack-api:0.1.0` y comparar con la tabla de `brewtrack-api`. |

Los hallazgos N-1 a N-7 del informe de seguridad no afectan a ningún CA. N-3 (sin tope de tiempo y sin limpieza ante `SIGKILL`) sí limita la garantía de CA-12 en un build abortado a la fuerza.

## Criterios sin prueba

- CA-11: sin build real de Jenkins (orden de etapas y artefacto revisados solo en el `Jenkinsfile`).
- CA-12 y CA-13 en Jenkins: probados con el script en local, no dentro de la etapa. La sintaxis del `Jenkinsfile` no pasó por el linter de Jenkins.
- CA-16, login con admin: pendiente de revisión humana.
- Casos límite funcionales (stock, 409, último admin): cubiertos solo por las suites, porque esta spec no toca esa lógica.

## Seguridad

Veredicto de `security-report.md`: APROBADO. Sin bloqueantes. Seis hallazgos no bloqueantes y uno informativo (N-1 a N-7), aceptados por D-5.

## Verificación de las mejoras

Rango `208e31e..HEAD`. `git diff --stat` toca `Jenkinsfile`, `scripts/slim-analysis.sh`, `reports/` y documentos de la spec. No toca `api/` ni `web/`, así que no se repitieron `pytest` ni `flutter`.

| Ítem | Estado | Evidencia |
|---|---|---|
| F-1 | Cerrado | `reports/image-analysis.md` usa solo MB decimales y lo declara ("MB = 10^6 bytes"). La capa más grande del resumen es la mayor fila de cada tabla: api 100,7 MB (base Debian; la siguiente es 94,6), web 49,3 MB (la siguiente es 44,7), db 280,3 MB. |
| CA-10 | Pasa | El script da 294 MB / 11 capas / 280 MB (db), 242 MB / 8 / 100 MB (api) y 108 MB / 11 / 49 MB (web). El informe da 294,1, 242,8 y 108,1 MB con las mismas capas y la misma capa mayor. El script trunca a MB enteros; el informe lleva un decimal, sin contradicción. |
| CA-12 | Pasa en local; sin prueba en Jenkins real | Tras el caso de éxito (rc 0) y el de fallo, `docker ps -a --filter name=slim-dind` y `docker network ls --filter name=slim-dind` salen vacíos. |
| CA-13 | Pasa en local; sin prueba en Jenkins real | Con `localhost/nope:9.9.9` el script sale con rc 1 ("No such image"). |
| Jenkinsfile | Pasa | Orden Trivy imágenes (83), SlimToolkit imágenes (97), Deploy minikube (105). `options { timeout(time: 15, unit: 'MINUTES') }` va como primera directiva dentro de `stage`, posición válida en sintaxis declarativa. Sin linter de Jenkins disponible. |
| CA-11 | Pendiente de prueba humana | Requiere un build real de Jenkins. |
| CA-16 | Pendiente de prueba humana | Login de admin: no hay credenciales sin leer `.env`. |

Veredicto: APROBADO. F-1 queda cerrado y CA-10, CA-12 y CA-13 siguen en Pasa. Quedan CA-11 y CA-16 para prueba humana; no bloquean.
