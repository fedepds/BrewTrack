# 001 — Informe de QA

Veredicto: **APROBADO**

Spec v1.1, commits 822488d..60f9e73. No hay fallos. Hay cuatro huecos de prueba de severidad baja (ver abajo).

## Ejecución

| Comando | Resultado |
|---|---|
| `pytest` (Postgres en localhost:55432) | 68 pasan |
| `flutter test` | 15 pasan |
| `flutter analyze` | Sin problemas |
| Stack con Podman | No ejecutado, por indicación. Se toman las notas del developer (`api` sano, `/health` ok, 401 sin token, tzdata presente). |

Todas las pruebas están en `api/tests/test_stats.py` (API), `web/test/stats_screen_test.dart`, `web/test/shell_test.dart` y `web/test/util_test.dart` (web).

## Criterios de aceptación

| CA | Prueba o verificación | Resultado |
|---|---|---|
| CA-1 | `test_stats.py::test_requires_auth` (401 y claves `code`, `message`) | Pasa |
| CA-2 | `test_stats.py::test_both_roles[roaster]` | Pasa |
| CA-3 | `test_stats.py::test_both_roles[admin]` | Pasa |
| CA-4 | `test_stats.py::test_bad_month_is_422[2026-13]` | Pasa |
| CA-5 | `test_stats.py::test_bad_month_is_422[octubre]` | Pasa |
| CA-6 | `test_stats.py::test_received_counts_only_the_month` | Pasa |
| CA-7 | `test_stats.py::test_roasted_counts_only_the_month` | Pasa |
| CA-8 | `test_stats.py::test_loss_is_weighted_not_averaged` ("12.00") | Pasa |
| CA-9 | `test_stats.py::test_stock_today_matches_lot_listing` (otros datos: dos lotes llenos de tuestes y uno sin ellos; mismo cálculo, `count().filter(stock > 0)`) | Pasa. Ver nota 1 |
| CA-10 | `test_stats.py::test_stock_today_matches_lot_listing` (compara con `/green-lots`) | Pasa |
| CA-11 | `test_stats.py::test_month_edges_use_workshop_timezone` (31-10 22:00 BA cuenta en 2026-10, no en 2026-11) | Pasa |
| CA-12 | `test_stats.py::test_month_edges_use_workshop_timezone` (01-10 00:00 BA cuenta en 2026-10, no en 2026-09) | Pasa |
| CA-13 | `test_stats.py::test_empty_month_returns_zeros[2020-01]` | Pasa |
| CA-14 | `test_stats.py::test_empty_month_returns_zeros[2099-01]` | Pasa |
| CA-15 | `test_stats.py::test_default_month_is_current_in_workshop_timezone` | Pasa |
| CA-16 | `test_stats.py::test_timezone_default_and_validation` (prueba el valor por defecto de `Settings`) y revisión de `stats.py` (usa `settings.timezone`) | Pasa. Ver nota 2 |
| CA-17 | Igualdad exacta de cadenas en las pruebas de CA-6 a CA-14 y revisión de `_kg` (`quantize(0.001)`) y de la merma (`quantize(0.01)`) | Pasa |
| CA-18 | `stats_screen_test.dart::muestra las cinco cifras con formato` | Pasa |
| CA-19 | mismo test (`textContaining('hoy')` encuentra 2) | Pasa |
| CA-20 | `stats_screen_test.dart::merma nula se muestra como guion` | Pasa |
| CA-21 | `stats_screen_test.dart::las flechas cambian de mes...` (selector "octubre 2026", "siguiente" nula) | Pasa |
| CA-22 | mismo test (septiembre 2026, pide `2026-09`, "siguiente" activa) | Pasa |
| CA-23 | mismo test (vuelve a octubre 2026, "siguiente" desactivada) | Pasa |
| CA-24 | `shell_test.dart::roaster ve Resumen después de Tuestes` | Pasa |
| CA-25 | `shell_test.dart::admin ve Resumen entre Tuestes y Usuarios` | Pasa |
| CA-26 | Revisión de `web/lib/router.dart`: el `redirect` envía a `/lots` tras el login y `/splash`, y no se tocó. Sin prueba propia | Pasa por revisión |

Los RF-8 a RF-10 (`TIMEZONE`, límites de mes) y RF-25 (mensaje del backend) quedan cubiertos por las pruebas de CA-11, CA-12, CA-15 y por `stats_screen_test.dart::un error de la API muestra el mensaje del backend`.

## Constitución

| Regla | Resultado | Evidencia |
|---|---|---|
| Alcance (sin curvas, empaque y venta, recetas y cata, multi-empresa) | Cumple | El diff solo agrega resumen de lotes y tuestes. |
| Stock calculado, sin columna | Cumple | `stats.py` usa `GreenLot.received_kg - used_expr()`. El diff no toca `models.py` ni migraciones. |
| Permisos impuestos en la API | Cumple | El router lleva `dependencies=[Depends(current_user)]`. Pruebas con `roaster`, `admin` y sin token (CA-1 a CA-3). El endpoint no distingue rol, como pide RF-12. |
| Errores 401 y 422 con `{"error": {"code", "message"}}` | Cumple | `test_requires_auth` y `test_bad_month_is_422` (`code == validation_error`). No hay 404, 403 ni 409 posibles en este endpoint. |
| Migración nueva, sin editar las previas | No aplica | Sin cambio de esquema. `api/alembic/versions` solo tiene `0001_initial_schema.py`, sin modificar. |
| Sin credenciales ni `.env` | Cumple | El diff agrega `TIMEZONE` a `.env.example` y `compose.yaml`, que no es secreto. `.env` no se leyó. |
| Imagen sin root y `/health` | Cumple parcialmente | `api/Containerfile` tiene `USER app`. El developer informa `/health` ok y tzdata presente. No lo repetí, por indicación. |
| Idioma de comentarios y textos | Pendiente de revisión humana | Aprueba el PR Federico Pizarro. Los textos de la interfaz están en español. |

## Fallos

Ninguno.

## Huecos de prueba (severidad baja, no bloquean)

1. CA-9 usa otros números que la spec (lotes de 30, 20 y 7.25 kg). Cubre la misma regla; no es literal.
2. CA-16 se prueba sobre `Settings()`, no sobre una llamada al endpoint sin `TIMEZONE`. El código lee `settings.timezone`, así que el riesgo es mínimo.
3. Las pruebas de 422 comprueban `code`, no que `error` tenga exactamente `code` y `message` (el developer ya lo anotó).
4. CA-26 y que tocar "Resumen" navegue a `/stats` no tienen prueba. Tampoco la tiene que `Api.summary` omita `month` cuando es null.

Pendientes del developer que acepto como están: la pantalla no refresca el mes actual si queda abierta durante el cambio de mes, y las tarjetas de 240 px desbordan por debajo de unos 272 px. Ninguno contradice un RF ni un CA.

## Criterios sin prueba directa

CA-26 (solo revisión). CA-16 (solo a nivel de `Settings`). No probé la pantalla con sesión real en el stack, porque la base del stack no tiene usuarios (ver `dev-notes.md`).
