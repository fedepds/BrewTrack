# BrewTrack

Trazabilidad de café de especialidad: lotes de café verde y tuestes. API FastAPI + frontend Flutter Web + PostgreSQL, con Podman.

## Arrancar

```bash
cp .env.example .env   # y rellenar POSTGRES_PASSWORD y JWT_SECRET
podman compose up --build -d
podman compose exec api python -m app.cli create-admin --email tu@correo.dev --name "Tu Nombre"
```
Abrir http://localhost:8080.

## Desarrollo

```bash
podman compose up -d db                       # solo la base de datos
cd api && . .venv/bin/activate && pytest      # requiere el Postgres de pruebas (ver docs/superpowers/plans, Task 2)
cd api && uvicorn app.main:app --reload       # DATABASE_URL y JWT_SECRET en el entorno
cd web && flutter run -d chrome --web-port 5000 --dart-define=API_BASE=http://localhost:8000/api/v1
cd web && flutter test
```

## Backup

```bash
podman compose exec db pg_dump -U brewtrack brewtrack > backup-$(date +%F).sql
```
