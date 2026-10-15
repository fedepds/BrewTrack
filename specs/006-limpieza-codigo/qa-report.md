# 006 — Informe de QA

Veredicto: APROBADO CON OBSERVACIONES

Los CA 1 a 23 cumplen. CA-24 queda sin verificar: no pude correr `kubectl apply --dry-run=client` contra un clúster que responda. CA-22 lo comprobé por el proxy con curl, no en un navegador. Base de la comparación: commit `e4731a6`.

## Criterios de aceptación

| CA | Resultado | Evidencia |
|---|---|---|
| 1 | Cumple | Generé `app.openapi()` con el código de `e4731a6` (worktree temporal, `PYTHONPATH` fijo, comprobé `app.__file__`) y con el de la rama, con `sort_keys`. `diff` sin salida; 2123 líneas en cada uno |
| 2 | Cumple | `cd api && pytest`: 110 pasan. `flutter analyze`: "No issues found". `flutter test`: 15 pasan |
| 3 | Cumple | `test_new_lot_has_full_stock`: listado da 100. Lo corrí también contra el código de `e4731a6`: pasa |
| 4 | Cumple | Mismo test: el 201 trae `stock_kg` 100 |
| 5 | Cumple | `test_stock_after_create_edit_delete_roast`: detalle de lote y listado dan 70 |
| 6 | Cumple | Mismo test: `lot.stock_kg` del detalle del tueste da 70 |
| 7 | Cumple | Mismo test: tras `PATCH` a 40, los tres sitios dan 60 |
| 8 | Cumple | Mismo test: tras borrar como admin, detalle y listado dan 100 |
| 9 | Cumple | `test_patch_lot_returns_current_stock`: `PATCH` `received_kg` 120 da 90 en la respuesta y en el detalle |
| 10 | Cumple | `test_patch_lot_without_received_kg_returns_current_stock`: solo `notes`, da 70 |
| 11 | Cumple | `test_summary_matches_lot_list`: dos lotes (70 y 0), `stock_kg` 70 y `lots_in_stock` 1 igualan la suma del listado. `test_stats.py` no cambió (`git diff --stat`) y pasa |
| 12 | Cumple | `test_roast_over_stock_is_rejected_and_stock_unchanged` compara el cuerpo completo: 409, `insufficient_stock`, "Stock disponible: 70.000 kg" (alta de 71) y "100.000 kg" (edición a 101). Los 6 tests de `test_stock.py` pasan también contra `e4731a6`, así que el código y el mensaje son los de antes. Stock 70 después |
| 13 | Cumple con observación | `grep -rn "stock_kg *=" api/app/routers`: solo `stats.py:75`, `stock_kg=_kg(stock_total)`. Es el argumento con que se construye la respuesta `Summary`, no una asignación al lote. Ver observación 2 |
| 14 | Cumple | `test_token_lifetimes`: `exp - iat` 3600 y 604800. `security.py:11-12` fija 60 min y 7 días |
| 15 | Cumple | `grep -i ttl api/app/config.py`: sin resultados |
| 16 | Cumple | `web/pubspec.yaml` sin `cupertino` ni comentarios de plantilla; `uses-material-design: true` se conserva. `pubspec.lock` nombra `cupertino_ui` (paquete del SDK de Flutter), no `cupertino_icons` |
| 17 | Cumple | `web/README.md` no existe |
| 18 | Cumple | `grep Paged web/lib web/test`: sin resultados. `.total` sin usos. `.items` solo queda como parámetro de `ResponsiveTable` (`widgets.dart:29`) |
| 19 | Cumple | `git diff --stat -- web/test`: vacío. Los 15 tests de widgets pasan |
| 20 | Cumple | `web/docker-entrypoint.d/` no existe. `git grep 10-api-host` fuera de `specs/` y `docs/superpowers/plans`: sin resultados |
| 21 | Cumple | `podman compose up --build -d`: `api` sano. `GET localhost:8081/api/v1/health` da 200 `{"status":"ok"}`. `localhost:8081/` da 200 y sirve el `index.html` de la SPA |
| 22 | Cumple por proxy (sin navegador) | Admin temporal creado con la CLI. Por `localhost:8081/api/v1`: login 200; listado de lotes (20, con `stock_kg`, p. ej. GL-2026-016 = 40.0); detalle de ese lote (stock 40.0, 2 tuestes); listado de tuestes (24); detalle de un tueste (lote GL-2026-006, `stock_kg` 114.0). Borré el admin temporal (`DELETE 1`; 0 filas con ese correo). No vi las pantallas |
| 23 | Cumple | Imagen `localhost/brewtrack-web:0.1.2`: `ENV API_HOST=api`. Tras el entrypoint de nginx, sin variable el `default.conf` trae `http://api:8000`; con `-e API_HOST=otrohost`, `http://otrohost:8000` |
| 24 | No verificado | Minikube arrancaba durante la prueba y el servidor no respondió: `kubectl apply --dry-run=client -f k8s/` falla en `brewtrack.yaml`, `monitoring.yaml` y `namespace.yaml` con "failed to download openapi ... connection reset by peer". No reintenté con `--validate=false` ni arranqué el clúster. La etiqueta de `web` es `0.1.2` en `compose.yaml:39` y `k8s/brewtrack.yaml:122` (y en `k8s/README.md:12,19`). `git diff k8s/brewtrack.yaml` muestra la etiqueta y el espacio final de `spec: ` (línea 7), que es del usuario; no lo toqué |

## Constitución

| Regla | Resultado | Evidencia |
|---|---|---|
| Stock calculado, nunca guardado | Cumple | `GreenLot.stock_kg` es un `column_property` (`models.py`, subconsulta con `coalesce(sum(green_in_kg))`). `alembic check` sobre la base migrada: "No new upgrade operations detected". `\d green_lots` en Postgres: 0 columnas con "stock". No se generó ni se editó ninguna migración (`git status api/alembic` vacío; 2 versiones) |
| Permisos en la API | Cumple | Sin endpoints nuevos; `openapi.json` idéntico (CA-1). Los tests de roles existentes pasan. Las respuestas de lectura por proxy exigen token |
| Formato de error | Cumple | CA-12 compara `{"error": {"code", "message"}}` completo |
| Migraciones | Cumple | Sin cambios; `upgrade head` aplica sobre base vacía y repetirlo no cambia nada; `downgrade base` limpia |
| Secretos | Cumple | No leí `.env`. La contraseña del admin temporal viajó solo por stdin y el entorno de mis comandos. `JWT_SECRET` sigue por entorno; los TTL ya no son secretos |
| Imagen `api` sin root, health con la imagen sola | Cumple | `podman exec brewtrack2-api-1 id`: `uid=1000(app)`. Health 200 |
| Alcance | Cumple | Solo borra y unifica; nada de curvas, empaque, venta, recetas, cata ni multi-empresa |
| Tokens 1 h y 7 días | Cumple | CA-14 |
| Idioma de comentarios y redacción | Pendiente de revisión humana | Aprueba el PR la persona usuaria |

## Fallos

Ninguno bloqueante.

## Observaciones

1. Baja. `db.refresh(lot)` en `create_lot` y `patch_lot` (`api/app/routers/green_lots.py`, tras `commit_or_409`) no hace falta hoy. Probé en una copia en el scratchpad sin el de `patch_lot`: los 6 tests de `test_stock.py` pasan igual. SQLAlchemy ya relee el `column_property` tras el `UPDATE` de `received_kg`, y `expire_on_commit=False` no lo impide. El comportamiento es correcto con y sin la línea. Consecuencia: ningún test falla si alguien la quita, así que no protege contra un cambio futuro de la sesión. No pide acción.
2. Baja. CA-13 busca "una asignación a `stock_kg`" en `routers/`. El grep literal `stock_kg *=` encuentra `stats.py:75`, que es un argumento con nombre del `Summary`. No asigna el stock de un lote. La persona decide si el CA se refería a esto.
3. Baja. `test_stock.py` cubre CA-3 a CA-12 con números concretos, pero el CA-12 de "edición" usa 101 sobre un lote de 100 (stock con exclusión del propio tueste), no 71 sobre 70. Cubre el caso de `exclude`, que es el que RF-8 señala. Sin acción.
4. Informativa. CA-24 y la vista en navegador de CA-22 quedan para cuando Minikube responda y una persona abra la web.

## Criterios sin prueba

- CA-24: sin clúster que responda.
- CA-22: sin navegador; probé el mismo flujo de datos por el proxy.
- Revisión humana de redacción y comentarios.

## Estado del entorno

- Dejé en marcha `brewtrack-test-db` (lo arranqué para pytest) y el stack de `compose`, reconstruido con el código de la rama.
- Admin temporal borrado. Worktree temporal eliminado. No hice commits ni modifiqué código, specs ni `k8s/brewtrack.yaml`.
