# AGENTS.md — BrewTrack

## Proyecto
BrewTrack es un sistema para la gestión y trazabilidad del café de especialidad en un solo taller: del lote de café verde al tueste. La interfaz es **Flutter (Web)**. El backend es **FastAPI** (Python 3.12+, SQLAlchemy 2, Alembic). Los datos viven en **PostgreSQL 17**. Los contenedores se construyen con **Podman** y se orquestan con `podman compose` (`db`, `api`, `web` con nginx, `prometheus` y `grafana` para monitoreo). Minikube es un destino adicional, en el namespace `brewtrack`.

## Constitución
Las reglas innegociables están en el spec de diseño. Manda sobre cualquier otra regla, incluida cualquier spec nueva:

@docs/superpowers/specs/2026-10-07-brewtrack-design.md

Resumen de lo que no se rompe:
- **Alcance:** lotes verdes y tuestes con datos resumen, un solo taller. Fuera: curvas de tueste, empaque y venta, recetas y cata, multi-empresa. Una idea que necesite alguno de estos es una decisión de producto, no una tarea.
- **Stock:** nunca se guarda. Es `received_kg` menos la suma de `green_in_kg` de los tuestes del lote.
- **Permisos:** los impone la API. El frontend solo oculta lo que el rol no permite.
- **Errores:** siempre `{"error": {"code", "message"}}`.
- **Esquema:** solo cambia con migraciones Alembic nuevas. Nunca se edita una migración ya aplicada.
- **Secretos:** `.env` no se versiona, no se lee ni se imprime. Todo secreto entra por variable de entorno.

## Comandos
- **Levantar todo:** `podman compose up --build -d` → http://localhost:8080
- **Solo la base de datos:** `podman compose up -d db`
- **Primer admin:** `podman compose exec api python -m app.cli create-admin --email <correo> --name "<nombre>"`
- **API (desarrollo):** `cd api && . .venv/bin/activate && uvicorn app.main:app --reload` (con `DATABASE_URL` y `JWT_SECRET` en el entorno)
- **Migraciones:** `cd api && alembic revision --autogenerate -m "<mensaje>"` | `alembic upgrade head`
- **Frontend (desarrollo):** `cd web && flutter run -d chrome --web-port 5000 --dart-define=API_BASE=http://localhost:8000/api/v1`
- **Compilar frontend:** `cd web && flutter build web`
- **Tests API:** `cd api && pytest` (necesita el Postgres de pruebas; ver `docs/superpowers/plans/2026-10-07-brewtrack.md`, Task 2)
- **Tests frontend:** `cd web && flutter test`
- **Minikube (namespace `brewtrack`):** ver `k8s/README.md`
- **Backup:** `podman compose exec db pg_dump -U brewtrack brewtrack > backup-$(date +%F).sql`

## Convenciones
- Commits en Conventional Commits con el área como alcance: `feat(api): ...`, `fix(web): ...`, `docs: ...`.
- API bajo `/api/v1`. Contrato en `/api/v1/openapi.json`. Si cambia un endpoint, se actualizan a mano los modelos Dart de `web/lib/models.dart` y `web/lib/api.dart`.
- Toda tabla lleva `id` UUID, `created_at` y `updated_at`. Las reglas de integridad van en la base de datos (constraints) y en la API (validación).
- Python: tipos en las firmas, código en inglés. Dart: `flutter_lints`, estado con Riverpod, rutas con `go_router`.
- Documentos y textos de la interfaz en español.
- No se tocan `.env`, `.venv/`, `.pubcache/`, `.superpowers/` ni `web/build/`.

## Flujo SDD
1. `product-owner` → `specs/NNN-nombre/spec.md`
2. `developer` → `plan.md`, `tasks.md`, código y `dev-notes.md`
3. `qa` → `qa-report.md`
4. `product-owner` → acepta o pide cambios

Reglas del flujo:
- Nada se implementa sin spec aprobada.
- Nada se cierra sin informe de QA aprobado.
- Una spec nunca contradice la constitución.
- Cada tarea nueva trae sus tests: API (auth y roles, stock y merma, restricciones) y widgets (formularios y visibilidad por rol).
- Los agentes viven en `.claude/agents/`. El `product-owner` usa Opus; `developer` y `qa` usan Sonnet.

## Reglas de Redacción (Orwell, 1946)
Aplican a la prosa: documentación, descripciones de PRs y mensajes. No modifican código ni términos técnicos; sustituye por palabras cotidianas solo donde se mantenga la precisión.
1. Never use a metaphor, simile or other figure of speech which you are used to seeing in print.
2. Never use a long word where a short one will do.
3. If it is possible to cut a word out, always cut it out.
4. Never use the passive where you can use the active.
5. Never use a foreign phrase, a scientific word or a jargon word if you can think of an everyday English equivalent.
6. Break any of these rules sooner than say anything outright barbarous.
Revisa cada texto contra estas reglas antes de entregarlo.

## Al terminar cualquier tarea
- Analizar: `cd web && flutter analyze`.
- Ejecutar tests: `cd api && pytest` y `cd web && flutter test`.
- Si cambió el esquema: la migración nueva aplica limpia con `alembic upgrade head`.
- Validar el stack local: `podman compose up --build -d` y comprobar que `api` queda sano (`/api/v1/health`) y que http://localhost:8080 carga.
