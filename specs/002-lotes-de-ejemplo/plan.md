# 002 — Plan

Spec: `spec.md` v1.1. Sin cambios de esquema, endpoints ni Flutter.

## Constitución

| Regla | Cómo la cumple este cambio |
|---|---|
| Alcance | Solo lotes verdes y tuestes con datos resumen. |
| Stock calculado | Se guardan `received_kg` y `green_in_kg`. Cada tueste pasa por `_check_stock`, que usa `used_kg` de `app/stock.py`. |
| Permisos en la API | Sin endpoints nuevos. La carga corre en el arranque y en `create-admin`; ningún cliente la dispara. |
| Formato de error | Sin respuestas nuevas. |
| Esquema | No cambia, no hay migración. La carga no va en una migración porque debe poder apagarse. |
| Secretos | `SEED_DEMO_LOTS` no es secreto. No se crean usuarios ni contraseñas. Los mensajes no incluyen `.env`. |

## Diseño

- `api/app/seed.py` guarda las dos tablas de la spec como tuplas.
  - `seed_lots` valida cada fila con `LotIn` y confirma una vez (todo o nada).
  - `seed_roasts` valida con `RoastIn`, comprueba stock con `_check_stock`, calcula `loss_pct` con `loss_pct` de `routers/roasts.py` y confirma una vez. Autor: usuario activo más antiguo (`created_at`, luego `id`).
  - `run_seed(lots=True)` devuelve las líneas de RF-15 y nunca lanza: cada carga corre en su sesión y un error se convierte en la línea `Error en la carga de ...`.
- `main.py`: `lifespan` llama a `run_seed()` y escribe en el logger `uvicorn.error`. Health responde después (RF-16).
- `cli.py`: `create_admin` llama a `run_seed(lots=False)` después de confirmar el admin e imprime las líneas.
- `config.py`: `seed_demo_lots: bool = False` (RF-2 fuera de compose).
- `compose.yaml`: `SEED_DEMO_LOTS: ${SEED_DEMO_LOTS:-true}`. `.env.example` documenta la variable.

## Pruebas

`api/tests/test_seed.py` copia las tablas de la spec y cubre CA-1 a CA-32. CA-33 a CA-35 son manuales (QA).
