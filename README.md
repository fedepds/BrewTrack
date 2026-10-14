# BrewTrack

Trazabilidad de café de especialidad: lotes de café verde y tuestes. API FastAPI + frontend Flutter Web + PostgreSQL, con Podman.

## Qué hace

BrewTrack lleva el registro de un taller de tueste, desde que llega el café verde hasta que sale tostado.

- **Lotes de café verde:** cada lote guarda su origen (país, región, finca, productor), variedad, proceso, altitud, cosecha y los kg recibidos.
- **Tuestes:** cada tueste anota de qué lote sale, quién lo hizo, cuánto verde entró y cuánto tostado salió, la duración, la temperatura de descarga y el nivel (`light`, `medium`, `dark`). La merma se calcula sola.
- **Stock:** la app no lo guarda, lo calcula: kg recibidos menos el verde usado en los tuestes. No deja tostar más de lo que queda.
- **Trazabilidad:** desde un lote se ven todos sus tuestes, y desde un tueste se llega a su lote de origen.
- **Resumen mensual:** cuánto verde queda hoy y, para el mes elegido, cuánto se recibió, cuánto se tostó y con qué merma.
- **Usuarios y roles:** `roaster` registra lotes y tuestes; `admin` además borra y gestiona usuarios. No hay registro abierto: un admin crea las cuentas.

Una base nueva arranca con 20 lotes y 24 tuestes de ejemplo para probar el sistema; la carga se puede apagar con una variable de entorno.

Fuera de alcance: curvas de tueste, empaque y venta, recetas y cata, y varias empresas en una misma instalación.

## Arrancar

```bash
cp .env.example .env   # y rellenar POSTGRES_PASSWORD, JWT_SECRET y GRAFANA_ADMIN_PASSWORD
podman compose up --build -d
podman compose exec api python -m app.cli create-admin --email tu@correo.dev --name "Tu Nombre"
```
Abrir http://localhost:8081.

## Monitoreo

Prometheus lee `/metrics` de la API cada 15 s. Grafana trae el panel "BrewTrack API" y seis alertas, sin pasos a mano. Ábrelo en http://127.0.0.1:3001 (usuario `admin`, contraseña `GRAFANA_ADMIN_PASSWORD`). Sin esa variable en `.env`, `grafana` no arranca. La configuración está en `monitoring/`; para cambiar un umbral edita `monitoring/grafana/provisioning/alerting/rules.yaml` y corre `podman compose restart grafana`.

Grafana guarda la contraseña de admin en su volumen la primera vez que arranca. Cambiar `GRAFANA_ADMIN_PASSWORD` después no la cambia. Para cambiarla, con `grafana` en marcha:

```bash
podman compose exec grafana sh -c 'grafana cli admin reset-admin-password "$GF_SECURITY_ADMIN_PASSWORD"'
```

Antes, actualiza `.env` y recrea el contenedor con `podman compose up -d grafana`. Si prefieres empezar de cero, borra el volumen con `podman compose down grafana && podman volume rm brewtrack2_grafanadata`.

En Minikube: ver `k8s/README.md`.

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
