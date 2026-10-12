# 002 — Informe de QA

Veredicto: **APROBADO CON OBSERVACIONES**

Spec v1.1, rama `feat/002-lotes-de-ejemplo`, commit a6666e9. Ningún CA de API falla. CA-33 a CA-35 se probaron por la API en un stack aparte (ver abajo).

## Ejecución

| Comando | Resultado |
|---|---|
| `cd api && pytest` (Postgres en 55432) | 96 pasan |
| `cd web && flutter analyze` | Sin problemas |
| `cd web && flutter test` | 15 pasan |
| Stack Podman (proyecto `bt002qa`, puerto 8093, volumen nuevo, env temporal sin `SEED_DEMO_LOTS`) | `api` sano, web 200, `/api/v1/health` 200, `SEED_DEMO_LOTS=true` por defecto. Borrados proyecto, volumen, imágenes y archivos. No toqué `brewtrack2`. |

## Criterios de aceptación

Pruebas en `api/tests/test_seed.py`. Revisé el código de `seed.py` contra las tablas RF-17 y RF-18 (valores copiados igual) y leí las pruebas de CA-24 a CA-30.

| CA | Prueba | Resultado |
|---|---|---|
| CA-1, CA-2 | `test_ca1_ca2_ca32_seeds_20_lots` | Pasa |
| CA-3 | `test_ca3_restart_keeps_lots` | Pasa |
| CA-4 | `test_ca4_real_lot_blocks_seed` | Pasa |
| CA-5 | `test_ca5_switch_off` | Pasa |
| CA-6 | `test_ca6_default_is_off` (`seed_demo_lots: bool = False`) | Pasa |
| CA-7 | `test_ca7_failed_lot_load_is_all_or_nothing` | Pasa |
| CA-8 | `test_ca8_lots_pass_post_rules` | Pasa |
| CA-9, CA-10, CA-22 | `test_ca9_ca10_ca22_create_admin_seeds_roasts` | Pasa |
| CA-11 | `test_ca11_boot_seeds_roasts_when_user_exists` | Pasa |
| CA-12 | `test_ca12_new_db_with_user` | Pasa |
| CA-13 | `test_ca13_no_users`, `test_ca13_inactive_user_does_not_count` | Pasa |
| CA-14 | `test_ca14_idempotent` | Pasa |
| CA-15 | `test_ca15_real_roast_blocks_seed` | Pasa |
| CA-16 | `test_ca16_missing_lot` | Pasa |
| CA-17 | `test_ca17_insufficient_stock` | Pasa |
| CA-18 | `test_ca18_off_in_create_admin` | Pasa |
| CA-19 | `test_ca19_failed_roast_load_keeps_admin` | Pasa |
| CA-20 | `test_ca20_oldest_active_user_is_author` | Pasa |
| CA-21 | `test_ca21_roasts_pass_post_rules` | Pasa |
| CA-23, CA-31 | `test_ca23_ca31_lots_listing` | Pasa |
| CA-24 | `test_ca24_stock_after_roasts` | Pasa |
| CA-25, CA-26 | `test_ca25_ca26_summary` (19, "1246.000", 5/57.000/48.150, 15.53, 15.34) | Pasa |
| CA-27 | `test_ca27_no_token` | Pasa |
| CA-28, CA-29 | `test_ca28_ca29_roast_permissions` (403 roaster, 204 admin, quedan 23) | Pasa |
| CA-30 | `test_ca30_lot_with_roasts_not_deletable` (409) | Pasa |
| CA-32 | `test_ca32_log_lines_for_cases` y las pruebas de cada caso | Pasa |
| CA-33 | Stack: al arrancar log "Se cargaron 20 lotes" y "omitida: no hay usuarios activos"; `create-admin` (llamando `create_admin` con contraseña de prueba) imprime "Se cargaron 24 tuestes". Por la API con login: 20 lotes, 24 tuestes, resumen 2026-10 = 19 lotes, "1246.000", 5 tuestes, 57.000/48.150, merma "15.53". GL-2026-013 stock 0. | Pasa por API. Pantallas no probadas |
| CA-34 | `restart` de `api`: log "omitida: la base ya tiene lotes" y "...tuestes"; siguen 20 y 24 | Pasa por API. Ver observación 4 |
| CA-35 | `received_kg` de GL-2026-013 a 20.000 por PATCH, reinicio: conserva 20.0, stock 5.0; siguen 20 y 24 | Pasa por API |

RF-2 (compose pone `true` por defecto): `compose.yaml` usa `SEED_DEMO_LOTS: ${SEED_DEMO_LOTS:-true}`. RF-3: `.env.example` documenta la variable. RF-16: la carga corre en el `lifespan`, antes de que la API atienda `/health`. RF-13/RF-15: `_guarded` captura todo error, devuelve una línea y `create-admin` imprime y devuelve el usuario; `Error ...` va al log con nivel ERROR.

## Constitución

| Regla | Resultado | Evidencia |
|---|---|---|
| Alcance (sin curvas, empaque y venta, recetas y cata, multi-empresa) | Cumple | `seed.py` solo carga `GreenLot` y `Roast`. |
| Stock calculado, sin columna | Cumple | La carga guarda `received_kg` y `green_in_kg`. Sin cambios en `models.py` ni migraciones. `_check_stock` valida el stock con la regla de `POST /roasts`. CA-24 y CA-25 pasan. |
| Permisos en la API | Cumple | Sin endpoints nuevos. CA-27 a CA-30 pasan con roaster, admin y sin token. |
| Errores con `{"error": {"code", "message"}}` | Cumple | Pruebas CA-27 a CA-30 (401, 403, 409). No hay 404 ni 422 nuevos. |
| Migración nueva, sin editar las previas | No aplica | Sin cambio de esquema. `alembic/versions` solo tiene `0001_initial_schema.py`, sin modificar. |
| Sin credenciales ni `.env` | Cumple | No leí `.env`. `.env` no está versionado. El diff solo agrega `SEED_DEMO_LOTS`. La carga no crea usuarios ni contraseñas. |
| Imagen de la API sin root y `/health` | Cumple parcialmente | `Containerfile` tiene `USER app` (revisión). `/health` no se verificó en el stack. |
| Idioma de comentarios y textos | Pendiente de revisión humana | Aprueba el PR Federico Pizarro. |

## Fallos

Ninguno en CA-1 a CA-32.

## Observaciones

1. **Severidad baja, nota del developer sobre RF-9.** Cumple RF-9 al pie de la letra: exige los 13 lotes "con su `code` y con la nota de RF-14". Si alguien edita la nota de `GL-2026-013` o de cualquiera de los 13 lotes, los tuestes se omiten con "faltan lotes de ejemplo", aunque el lote exista. La spec no tiene un CA para ese caso (CA-16 borra el lote; CA-17 edita `received_kg`). El mensaje puede confundir. Decisión del product-owner: dejarlo o pedir otro motivo.
2. **Severidad baja.** CA-6 se prueba comprobando que pytest no define la variable, no con `uvicorn` sin ella.
3. **Severidad baja.** CA-7 y CA-19 inyectan el fallo con `monkeypatch`; no se prueba un fallo real de la base.

4. **Severidad media, fuera del diff de 002.** Tras `restart` de `api`, nginx de `web` sigue con la IP vieja de `api` y responde 502 (`proxy_pass http://api:8000` sin `resolver`; vi la IP 10.89.11.3 contra la nueva 10.89.11.6). Con `podman compose restart api` la interfaz falla hasta reiniciar `web`. Por eso CA-34 y CA-35 por la interfaz, tal como los escribe la spec, no funcionan sin reiniciar `web`. Tras reiniciar `web` todo respondió bien. Devolver al developer.

## Criterios sin prueba

- Pantallas con sesión de CA-33 a CA-35: no tengo navegador; se probó la API (login, listas, resumen, edición) a través del proxy de nginx. La web cargó (200) pero no se vio el contenido.
- Healthcheck del contenedor `api`: sano en el stack. `USER app` solo por revisión del `Containerfile`.
