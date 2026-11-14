# Notas del desarrollador — 007

## Qué cambió
- `api/brewtrack-api.Containerfile`, `web/brewtrack-web.Containerfile`, `db/brewtrack-db.Containerfile`: etiquetas fijas.
- `Jenkinsfile`: etiquetas fijas (iguales a los `FROM`), etapa "SlimToolkit imágenes" y `archiveArtifacts`.
- `scripts/slim-analysis.sh` (nuevo).
- `reports/image-analysis.md` y `reports/slimtoolkit-ejecucion.md`, ahora versionados.
- `AGENTS.md`: línea CI/CD menciona SlimToolkit.

## Etiquetas elegidas
Todas comprobadas con `docker manifest inspect` (manifiesto con `arm64`).

| Uso | Etiqueta |
|---|---|
| api (build y final), tests API | `python:3.13.18-slim-trixie` |
| web build, tests web | `ghcr.io/cirruslabs/flutter:3.44.0` |
| web final | `nginx:1.31.8-alpine` |
| db, Postgres de los tests API | `postgres:17.11-alpine3.24` |
| Semgrep | `semgrep/semgrep:1.184.0` (la que corría, `latest` local) |
| Trivy | `aquasec/trivy:0.76.2` (la que corría) |
| dind y Slim | `docker:27.5.1-dind`, `dslim/slim:1.40.11` (solo amd64; corre emulada) |

## RF-12: sin los `upgrade`
Probé las tres imágenes sin `apt-get upgrade` y sin `apk upgrade`. Trivy falla en las tres: `zlib1g` en api (HIGH, con parche), `libxslt` en web y paquetes de Alpine (`krb5`, `libxslt`) en db. Los `upgrade` se quedan. La capa de api bajó de 12,4 a 5,3 MB.

## Verificación
| Comprobación | Resultado |
|---|---|
| `pytest` (Postgres de pruebas 55432) | pasa: 115 passed |
| `flutter analyze` | pasa: No issues found |
| `flutter test` | pasa: 38 tests |
| `docker compose up --build -d` | pasa: api healthy; `/api/v1/health` 200; `/lotes` 200 |
| CA-1 | **falla solo para db**: ver Preguntas abiertas |
| CA-2 | pasa (sin salida) |
| CA-4 | pasa: api 2, web 2, db 1 |
| CA-6, CA-7 | pasa: app/1000, nginx/101, postgres/70 |
| CA-8 | pasa: Trivy sale 0 en las tres (db con `--skip-files usr/local/bin/gosu`) |
| CA-9 | pasa: Python 3.13.18, nginx 1.31.8, PostgreSQL 17.11 |
| CA-14 | pasa: solo `web` publica `0.0.0.0:8081->8080` |
| CA-15/16 | pasa: health 200, `/lotes` 200, `GET /api/v1/green-lots` sin token 401 con `{"error":{"code","message"}}`. El login con admin no se probó a mano. |
| CA-12, CA-13 (script en local) | pasa: éxito con las tres imágenes (rc 0) y fallo con `localhost/nope:9.9.9` (rc 1); en ambos `docker ps -a --filter name=slim-dind` sale vacío |
| Sintaxis `Jenkinsfile` | llaves balanceadas; el linter de Jenkins pide login y no lo corrí. No disparé un build real. |

## Pendiente
- CA-3, CA-5, CA-10, CA-11 los revisa QA (archivos y build de Jenkins).
- `docs/ci/jenkins.md`, que cita `AGENTS.md`, no existe en el repositorio.
- El contenedor `brewtrack-test-db` de pruebas usa `postgres:17-alpine`; el plan del proyecto lo define así y no lo cambié.

## Preguntas abiertas
1. **CA-1 contradice RF-1 para Postgres.** Postgres publica etiquetas `MAYOR.MENOR` (17.11), sin parche. La etiqueta `17.11-alpine3.24` no cumple el `grep` de CA-1 (`[0-9]+\.[0-9]+\.[0-9]+`) y sale como línea. La spec pide a la vez "versión mayor, menor y de parche" y esa salida vacía. Elegí `17.11-alpine3.24` (la versión exacta que corría) y no `postgres:17.11.0-...`, que no existe. Hace falta que el product-owner relaje CA-1 y RF-1 para Postgres (por ejemplo, aceptar `17.11-alpine3.24`) o indique otra etiqueta. Lo mismo vale para CA-2, que pide "mayor, menor y de parche" en cada imagen del `Jenkinsfile`.

## Mejoras tras seguridad y QA
Apliqué N-2 a N-5, N-7 y F-1. No cambia ningún requisito.
- `scripts/slim-analysis.sh`: red propia por ejecución para el Docker temporal (N-2); borrado de restos al inicio (N-3); `trap cleanup EXIT` con `exit 130` en `INT` y `exit 143` en `TERM` (N-4); `docker save` a un archivo en `$TMP` y `docker load` desde él, que se borra tras cargar (N-5).
- `Jenkinsfile`: `timeout` de 15 minutos en la etapa (N-3) y sin `allowEmptyArchive` (N-7).
- `reports/image-analysis.md`: todas las cifras de capas en MB decimales, medidas con `docker history --human=false` en el Docker temporal. La capa más grande de api es la base Debian (100,7 MB), de web 49,3 MB y de db 280,3 MB (F-1).
- `reports/slimtoolkit-ejecucion.md`: documenta red propia, limpieza al inicio y timeout.

Evidencia (local):
| Caso | Resultado |
|---|---|
| `sh -n scripts/slim-analysis.sh` | sin errores |
| Éxito con las tres imágenes | rc 0; `docker ps -a` y `docker network ls` con `--filter name=slim-dind` vacíos |
| Fallo con `localhost/nope:9.9.9` | rc 1; ambos listados vacíos |
| `SIGINT` a los 20 s | rc 130 en 3 s; ambos listados vacíos |
| `SIGTERM` a los 20 s | rc 143 en 3 s; ambos listados vacíos |

Un `kill -INT` a un trabajo en segundo plano de `sh` no llega al script (el shell lo lanza con `INT` ignorada); probé con `INT` restaurado desde Python.
