# 002 — Notas de desarrollo

## Qué cambió
- `api/app/seed.py` (nuevo): los 20 lotes y 24 tuestes, y la lógica de carga.
- `api/app/main.py`: `lifespan` carga lotes y tuestes al arrancar.
- `api/app/cli.py`: `create-admin` intenta la carga de tuestes después de crear el admin.
- `api/app/config.py`: `seed_demo_lots` (falso si no se define).
- `compose.yaml` y `.env.example`: `SEED_DEMO_LOTS`, `true` por defecto en compose.
- `api/tests/test_seed.py`: 28 pruebas (CA-1 a CA-32).

## Cómo probarlo
- `cd api && pytest` (necesita el Postgres de pruebas en el puerto 55432).
- Stack: `podman compose up --build -d`, `podman compose exec api python -m app.cli create-admin --email <correo>`. Quedan 20 lotes y 24 tuestes.

## Cifras de merma
Coinciden con la spec: octubre 15.53 y septiembre 15.34. Las pruebas CA-25 y CA-26 las verifican sin ajustes.

## Resultados
- `pytest`: 96 pruebas pasan (28 nuevas).
- `flutter analyze`: sin problemas. `flutter test`: 15 pasan.
- Stack (proyecto `bt002`, web en 8082 porque el 8080 estaba ocupado por otro stack): `/api/v1/health` sano, web responde 200. Con base nueva: 20 lotes al arrancar, "no hay usuarios activos" para los tuestes. Tras `create-admin`: 24 tuestes. Tras reiniciar `api`: siguen 20 y 24, y el log muestra las dos líneas "omitida". Se borró el stack y su volumen al terminar.

## Decisiones
- Un error de la carga (no un omitido) se escribe en el log del arranque con nivel ERROR, con la línea `Error en la carga de lotes|tuestes de ejemplo: ...`.
- Un lote cuenta como "de ejemplo" para los tuestes si tiene el `code` y la nota de RF-14 (RF-9).
- Una nota editada de `GL-2026-013` hace que se omitan los tuestes con "faltan lotes de ejemplo".

## Pendiente
- CA-33 a CA-35 por la interfaz (pantallas con sesión) quedan para QA. Solo se comprobaron la base y los logs.
- Los CA-1 a CA-32 se probaron con `TestClient`; CA-6 comprueba que pytest no define la variable.
