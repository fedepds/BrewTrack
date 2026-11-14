# Análisis de imágenes — BrewTrack

Fecha: 2026-11-14 (spec 007)
Herramienta: SlimToolkit 1.40.11 (`slim xray`) con `scripts/slim-analysis.sh`. Tamaños de `docker image inspect` y capas de `docker history`, ambos del Docker 27 temporal.
Imágenes: `localhost/brewtrack-api:0.1.0`, `localhost/brewtrack-web:rebranding`, `localhost/brewtrack-db:0.1.0` (linux/arm64).

## Resumen

| Imagen | Base fijada | Tamaño total | Capas | Capa más grande | Archivos duplicados |
|---|---|---|---|---|---|
| `brewtrack-api` | `python:3.13.18-slim-trixie` | 242,8 MB | 8 | 103 MB (dependencias de la app) | 2,2 MB |
| `brewtrack-web` | `nginx:1.31.8-alpine` (build: `ghcr.io/cirruslabs/flutter:3.44.0`) | 108,1 MB | 11 | 51,5 MB (paquetes de nginx, base) | 30 kB |
| `brewtrack-db` | `postgres:17.11-alpine3.24` | 294,1 MB | 11 | 280 MB (PostgreSQL, base) | 166 kB |

El tamaño es el de la imagen sin comprimir. `docker images` en Colima muestra cifras mayores porque el almacén de containerd cuenta también las capas comprimidas.

## brewtrack-api

Base `python:3.13.18-slim-trixie` (Python 3.13.18, Debian 13.7). Multi-stage: la etapa `build` instala el paquete con `pip --prefix` y la final solo copia `/install`.

| Capa | Tamaño | Origen |
|---|---|---|
| base | 110 MB | Debian trixie |
| base | 5 MB | certificados y tzdata |
| base | 43,8 MB | Python compilado |
| `RUN apt-get upgrade` | 5,3 MB | parches de Debian y borrado de `pip` |
| `COPY --from=build` | 103 MB | dependencias de la app |
| resto | 66 kB | `alembic.ini` y migraciones |

Optimizaciones posibles:
- `uvicorn[standard]` por `uvicorn` con `uvloop` y `httptools`: unos 10 MB. `websockets`, `watchfiles`, `pyyaml` y `python-dotenv` no se usan en producción.
- Capa de `apt-get upgrade` (5,3 MB): sin optimización que compense. Con la etiqueta fijada Trivy sigue marcando `zlib1g` (HIGH, con parche en Debian), así que la capa se queda (RF-12).
- Binarios con setuid (`su`, `passwd`, `mount`, …) y shells: sin optimización que compense. El proceso corre como `app` (uid 1000) y quitarlos exige una base distroless que cambia el arranque.

## brewtrack-web

Base `nginx:1.31.8-alpine` (nginx 1.31.8, Alpine 3.24.4). Multi-stage: la etapa `build` (`flutter:3.44.0`) compila y la final solo copia `build/web`.

| Capa | Tamaño | Origen |
|---|---|---|
| base | 9,3 MB | Alpine |
| base | 6 MB | usuario nginx |
| base | 51,5 MB | paquetes de nginx |
| `COPY --from=build` | 44,9 MB | app Flutter compilada |
| `RUN apk upgrade` | 0,8 MB | parches de Alpine y ajustes para correr sin root |

Optimizaciones posibles:
- Borrar los `*.symbols` de `canvaskit/` (símbolos de depuración): unos 5 MB.
- Quitar motores de render que ningún navegador del taller usa: hasta 20 MB, pero puede romper algún navegador y necesita pruebas. Sin optimización que compense por ahora.
- `main.dart.js` (2,9 MB) y recursos (2,4 MB): sin optimización que compense.

## brewtrack-db

Base `postgres:17.11-alpine3.24` (PostgreSQL 17.11, Alpine 3.24.4). Una sola etapa.

| Capa | Tamaño | Origen |
|---|---|---|
| base | 9 MB | Alpine |
| base | 2 MB | usuario postgres y gosu |
| base | 280 MB | PostgreSQL compilado |
| base | 79 kB | configuración y scripts |
| `RUN apk upgrade` | unos 3 MB | parches de Alpine |

Optimizaciones posibles: sin optimización que compense. El 95 % es la capa oficial de PostgreSQL, que incluye LLVM para JIT, y reducirla obliga a compilar PostgreSQL propio. `gosu` sigue en la imagen aunque no se usa al correr sin root (riesgo aceptado en `docs/security/2026-11-10-imagen-db.md`).

Por qué una sola etapa (D-4): `db` no compila nada. Una segunda etapa copiaría la imagen entera sin ahorrar un byte.

## Estado frente a los requisitos

| Requisito | api | web | db |
|---|---|---|---|
| Un Containerfile por componente | sí | sí | sí |
| Versión fija (no `latest`) | sí | sí | sí |
| Sin root | sí (`app`, uid 1000) | sí (`nginx`, uid 101) | sí (`postgres`, uid 70) |
| Multi-stage | sí | sí | excepción: una etapa, no compila nada (D-4) |
| Trivy (HIGH y CRITICAL, sin parche ignorado) | sí | sí | sí (salta `gosu`) |
| SlimToolkit | sí | sí | sí |

Cada build de Jenkins regenera este análisis en `image-analysis.md` (artefacto). Cómo repetirlo: `reports/slimtoolkit-ejecucion.md`.
