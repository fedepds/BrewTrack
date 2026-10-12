# BrewTrack — Design (v1)

## Objetivo

Sistema para la gestión y trazabilidad de café de especialidad en un solo taller: del lote de café verde al tueste. API en FastAPI, frontend en Flutter Web, datos en PostgreSQL, contenedores con Podman.

## Alcance v1

Dentro:
- Lotes de café verde, tuestes con datos resumen (sin curva).
- Un solo taller, login con roles `roaster` y `admin`.

Fuera:
- Curvas tiempo-temperatura y captura en vivo desde la tostadora.
- Empaque y venta, recetas y cata.
- Multi-empresa (multi-tenant).
- CI/CD, TLS y backups automáticos.

## Arquitectura

Tres contenedores: `db` (PostgreSQL), `api` (FastAPI), `web` (Flutter Web servido por nginx, con proxy `/api/` hacia `api:8000`). Solo `web` publica puerto al host.

## Modelo de datos

Todas las tablas llevan `id` UUID, `created_at` y `updated_at`.

**users**: `email` (único), `password_hash` (argon2), `name`, `role` (`roaster` | `admin`), `active`.

**green_lots**: `code` (único, p. ej. `GL-2026-014`), `origin_country`, `region`, `farm`, `producer`, `variety`, `process`, `altitude_m` (opcional), `harvest_year`, `received_at`, `received_kg`, `notes`. El stock actual no se almacena: `received_kg` menos la suma de `green_in_kg` de sus tuestes.

**roasts**: `lot_id` → `green_lots` (`ON DELETE RESTRICT`), `roasted_at`, `roaster_id` → `users`, `green_in_kg`, `roasted_out_kg`, `loss_pct` (calculado en la API), `duration_s`, `drop_temp_c`, `roast_level` (`light` | `medium` | `dark`), `notes`.

Integridad:
- Constraints en BD: `roasted_out_kg <= green_in_kg`, pesos y tiempos > 0.
- Validación en API: un tueste no puede superar el stock disponible del lote.
- Índices en `roasts(lot_id)` y `roasts(roasted_at)`.
- Migraciones con Alembic.

## API (`/api/v1`)

Contrato OpenAPI en `/api/v1/openapi.json`.

Auth:
- `POST /auth/login` → JWT de acceso (1 h) y refresh token (7 días).
- `POST /auth/refresh`, `GET /auth/me`.
- Sin auto-registro. Los usuarios los crea un admin. El primer admin se crea con la CLI `create-admin`.

| Recurso | Endpoints | Permisos |
|---|---|---|
| users | `GET/POST /users`, `PATCH /users/{id}` | admin |
| green-lots | `GET` (lista y detalle), `POST`, `PATCH` | ambos roles |
| green-lots | `DELETE` | admin |
| roasts | `GET` (lista y detalle), `POST` | ambos roles |
| roasts | `PATCH` | autor del tueste o admin |
| roasts | `DELETE` | admin |

Trazabilidad:
- El detalle de un lote devuelve el stock calculado y sus tuestes.
- El detalle de un tueste incluye los datos de su lote de origen.

Listados:
- Paginación con `limit` y `offset`.
- Filtros en `roasts`: lote, fecha y nivel.
- Filtros en `green-lots`: país y proceso.

Errores y seguridad:
- Formato de error único: `{"error": {"code", "message"}}`. Códigos 401, 403, 404, 409 (borrar lote con tuestes) y 422.
- CORS cerrado al origen del frontend (solo relevante en desarrollo).
- Secreto JWT desde variable de entorno.
- `GET /health` para healthchecks.

## Frontend (Flutter Web)

Stack: `flutter_riverpod`, `go_router` (redirección a login sin sesión), `dio` con interceptor de JWT y refresh en 401. Modelos Dart escritos a mano (sin generar cliente OpenAPI en v1). Material 3 con paleta café. Token de acceso en memoria, refresh token en `localStorage`.

Pantallas:
1. Login.
2. Lotes verdes: tabla con filtros (país, proceso), stock visible, alta y edición.
3. Detalle de lote: datos, stock, lista de tuestes, alta de tueste con el lote preseleccionado.
4. Tuestes: tabla con filtros (lote, fechas, nivel), formulario con merma calculada en vivo, detalle con lote de origen enlazado.
5. Usuarios (solo admin): lista, alta, activar o desactivar.

Comportamiento:
- Se ocultan acciones y rutas que el rol no permite. La API impone los permisos.
- Los errores 409 y 422 se muestran con el mensaje del backend.
- Responsive: tabla en escritorio y tarjetas en pantallas estrechas.

## Contenedores y estructura

```
brewtrack/
├── api/            # FastAPI, Alembic, tests, Containerfile
├── web/            # Flutter Web, nginx.conf, Containerfile
├── compose.yaml    # db + api + web
├── .env.example
└── docs/superpowers/specs/
```

| Servicio | Imagen | Notas |
|---|---|---|
| db | `postgres:17-alpine` | Volumen `pgdata`, healthcheck `pg_isready`. |
| api | `python:3.13-slim` multi-stage | Usuario no root. Arranque: `alembic upgrade head` y luego `uvicorn`. Espera a `db` sano. Healthcheck en `/api/v1/health`. |
| web | build `ghcr.io/cirruslabs/flutter`, runtime `nginx:alpine` | `flutter build web --release`. nginx sirve la SPA con fallback a `index.html` y hace proxy de `/api/`. |

- Archivos `Containerfile`, flujo `podman compose up --build`, modo rootless.
- Destino adicional: Minikube, en el namespace `brewtrack`, con las mismas imágenes. Compose sigue siendo el principal. Los secretos entran por un Secret de Kubernetes creado desde `.env`, nunca escritos en los manifiestos.
- Configuración en `.env` (no versionado): `POSTGRES_PASSWORD`, `JWT_SECRET`, `DATABASE_URL`. Plantilla en `.env.example`.
- Primer admin: `podman compose exec api python -m app.cli create-admin`.
- Backup documentado con `pg_dump`.

Desarrollo:
- Solo `db` por Podman. `uvicorn --reload` y `flutter run -d chrome` en el host.

## Pruebas

- API: pytest contra un Postgres real (misma imagen). Cubre auth y roles, cálculo de stock y merma, y restricciones (tueste que supera el stock, borrado de lote con tuestes).
- Frontend: pruebas de widgets para login, formulario de tueste (cálculo de merma) y visibilidad por rol. Sin tests de integración en v1.
