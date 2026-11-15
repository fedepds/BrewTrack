# Plan 007 — Salidas de café tostado

> **Para agentes:** SUB-SKILL REQUERIDA: usa superpowers:subagent-driven-development (recomendada) o superpowers:executing-plans para ejecutar este plan tarea por tarea. Los pasos usan casillas (`- [ ]`) para seguir el avance.

**Objetivo:** cada tueste muestra su stock tostado y ambos roles registran salidas (venta, consumo, otro) contra él, sin pasar del stock.

**Arquitectura:** tabla nueva `roast_withdrawals` con migración `0002`. El stock tostado es un `column_property` en `Roast` (`roasted_out_kg` menos la suma de las salidas), igual que `GreenLot.stock_kg`. Los endpoints nuevos viven en `routers/roasts.py`, bajo `/roasts/{roast_id}/withdrawals`. En el frontend, el detalle del tueste suma la sección de salidas con un diálogo hecho con `showEditDialog`.

**Stack:** FastAPI, SQLAlchemy 2, Alembic, PostgreSQL 17, Flutter Web (Riverpod, `edit_dialog.dart`).

**Spec:** `specs/007-salidas-de-tostado/spec.md`

## Restricciones globales

- El stock tostado nunca se guarda: es `roasted_out_kg` menos la suma de `kg` de las salidas del tueste.
- `kg`: `Numeric(10, 3)`, `> 0`. `reason`: `sale` | `consumption` | `other`, con constraint en la base.
- `roast_withdrawals.roast_id` → `roasts` con `ON DELETE RESTRICT`, con índice `ix_roast_withdrawals_roast_id`.
- Errores con el formato `{"error": {"code", "message"}}`. Códigos nuevos: `insufficient_roasted_stock` (409), `roast_has_withdrawals` (409), `not_found` (404).
- Crear salidas: ambos roles. Borrar: solo admin. No se pueden editar.
- Migración nueva `0002`. No se toca `0001`.
- Textos de la interfaz en español: "Stock tostado", "Salidas", "Registrar salida", motivos "Venta", "Consumo", "Otro".
- No se agregan dependencias.

## Constitución

| Regla | Cómo la cumple |
|---|---|
| Alcance | Las salidas no llevan precio, cliente ni factura (spec 007, D-4). |
| Stock calculado | `Roast.roasted_stock_kg` es un `column_property`; no existe ninguna columna de stock. |
| Permisos en la API | `DELETE` usa `admin_only`. El frontend solo oculta el botón. |
| Errores | Usa `ApiError`. |
| Migraciones | `0002_roast_withdrawals.py`, nueva. |
| Secretos | No hay. |

## Puntos a revisar

Casos que la spec implica y que conviene cubrir con un test (cada uno va en la tarea que lo posee):

1. Una salida igual al stock exacto se acepta y deja el stock en 0. Después, cualquier salida da 409. (Tarea 2)
2. `DELETE` de una salida usando el id de otro tueste da 404, aunque la salida exista. (Tarea 2)
3. `kg` con 4 decimales (`0.0001`) da 422, no se redondea. (Tarea 2)
4. Bloqueo `FOR UPDATE` sobre `Roast`: sus relaciones `lazy="joined"` generan `LEFT OUTER JOIN`, y Postgres rechaza `FOR UPDATE` en ese caso. Hay que bloquear solo la tabla de tuestes: `db.get(Roast, id, with_for_update={"of": Roast})`. Cubre el POST de salida y el PATCH de tueste. (Tarea 2)
5. En el formulario, salir con exactamente el stock disponible escrito con coma (`2,5` con stock 2.5) se permite. Pasarse por 0,001 no. (Tarea 3)

---

### Task 1: Modelo, migración y stock tostado

**Archivos:**
- Modificar: `api/app/models.py`
- Crear: `api/alembic/versions/0002_roast_withdrawals.py`
- Modificar: `api/app/stock.py`
- Test: `api/tests/test_models.py`

**Interfaces:**
- Produce: `RoastWithdrawal` (`roast_id`, `user_id`, `withdrawn_at`, `kg`, `reason`, `notes`, `user: User` con `lazy="joined"`, propiedad `user_name`). `Roast.withdrawals: list[RoastWithdrawal]` ordenadas por `withdrawn_at` descendente. `Roast.roasted_stock_kg: Decimal` (`column_property`). `withdrawn_kg(db: Session, roast_id: uuid.UUID) -> Decimal` en `app/stock.py`.

- [ ] **Paso 1: tests que fallan** en `test_models.py`:
  - `test_withdrawal_kg_and_reason_constraints`: `kg=0` y `reason="gift"` dan `IntegrityError`.
  - `test_roast_with_withdrawals_cannot_be_deleted_in_db`: borrar el tueste da `IntegrityError`.
  - `test_roasted_stock_is_out_minus_withdrawals`: tueste con `out="8.5"` y salidas de 2 y 1.5 → `roasted_stock_kg == Decimal("5.000")`. Sin salidas → `8.5`.
- [ ] **Paso 2:** `cd api && pytest tests/test_models.py -v` → FALLA (no existe `RoastWithdrawal`).
- [ ] **Paso 3:** agrega `RoastWithdrawal(Base, Timestamps)`, tabla `roast_withdrawals`, constraints `ck_withdrawals_kg` (`kg > 0`) y `ck_withdrawals_reason`, e índice. Agrega `Roast.roasted_stock_kg` junto a `GreenLot.stock_kg` con el mismo patrón (`coalesce(sum)`, `correlate_except`). Agrega `withdrawn_kg` en `stock.py`, igual que `used_kg` pero sin `exclude`.
- [ ] **Paso 4:** `cd api && alembic revision --autogenerate -m "roast withdrawals"`. Renombra el archivo a `0002_roast_withdrawals.py` con `revision = '0002'` y `down_revision = '0001'`. Revisa que `downgrade` borre la tabla y el índice.
- [ ] **Paso 5:** `cd api && pytest -v` → todo PASA (el fixture aplica `upgrade head` y `downgrade base`).
- [ ] **Paso 6:** commit `feat(api): tabla roast_withdrawals y stock tostado calculado`.

### Task 2: Endpoints de salidas y reglas en tuestes

**Archivos:**
- Modificar: `api/app/schemas.py`, `api/app/routers/roasts.py`
- Crear: `api/tests/test_withdrawals.py`

**Interfaces:**
- Consume: tarea 1.
- Produce (JSON):
  - `WithdrawalOut`: `id`, `roast_id`, `user_id`, `user_name`, `withdrawn_at`, `kg` (número), `reason`, `notes`.
  - `RoastOut` suma `roasted_stock_kg` (número). `RoastDetail` suma `withdrawals: list[WithdrawalOut]`.
  - `GET /roasts/{roast_id}/withdrawals` → `list[WithdrawalOut]`, de la más nueva a la más vieja.
  - `POST /roasts/{roast_id}/withdrawals` (cuerpo `withdrawn_at`, `kg`, `reason`, `notes?`) → 201 `WithdrawalOut`.
  - `DELETE /roasts/{roast_id}/withdrawals/{withdrawal_id}` → 204.

- [ ] **Paso 1: tests que fallan** en `test_withdrawals.py`, con los fixtures de `conftest.py` y un helper `make_withdrawal` local:
  - `test_roaster_creates_withdrawal_and_stock_drops`: POST de 2 kg sobre un tueste de 8.5 → 201, `user_name == "roaster"`, y el detalle del tueste da `roasted_stock_kg == 6.5` y una salida.
  - `test_withdrawal_cannot_exceed_roasted_stock`: 9 kg sobre 8.5 → 409 `insufficient_roasted_stock`, y el mensaje contiene `8.5`.
  - `test_withdrawal_may_take_exact_stock`: 8.5 → 201. Después, `0.001` → 409. (Punto 1)
  - `test_withdrawal_validation`: `kg: 0`, `kg: 0.0001`, `reason: "gift"` → 422. (Punto 3)
  - `test_withdrawal_unknown_roast_is_404`.
  - `test_delete_withdrawal_is_admin_only`: el roaster recibe 403. El admin recibe 204 y el stock vuelve a 8.5.
  - `test_delete_withdrawal_of_other_roast_is_404`. (Punto 2)
  - `test_list_withdrawals_newest_first`.
  - `test_roast_with_withdrawals_cannot_be_deleted`: 409 `roast_has_withdrawals`.
  - `test_patch_roast_out_below_withdrawn_is_409`: retirados 5, PATCH `roasted_out_kg: 4` → 409 `insufficient_roasted_stock`. PATCH a `5` → 200. (Punto 4: el PATCH bloquea el tueste)
  - `test_withdrawals_require_auth`: GET sin token → 401.
- [ ] **Paso 2:** `cd api && pytest tests/test_withdrawals.py -v` → FALLA (404 en las rutas).
- [ ] **Paso 3:** implementa en `roasts.py`:
  - `WithdrawalIn` con `kg: Decimal = Field(**Kg)`, `reason: Literal["sale", "consumption", "other"]`, `withdrawn_at: datetime`, `notes: str | None = None`.
  - POST: bloquea con `db.get(Roast, roast_id, with_for_update={"of": Roast})` (404 `not_found` si no existe). Disponible = `roast.roasted_out_kg - withdrawn_kg(db, roast.id)`. Si `kg` lo supera → `ApiError(409, "insufficient_roasted_stock", f"Stock tostado disponible: {available} kg")`. `user_id` sale del token.
  - DELETE con `dependencies=[Depends(admin_only)]`. Busca la salida por id y por `roast_id`; si no coincide → 404 `not_found`.
  - `delete_roast`: si hay salidas → `ApiError(409, "roast_has_withdrawals", "El tueste tiene salidas y no se puede borrar")`, con el mismo patrón `exists()` que `delete_lot`.
  - `patch_roast`: bloquea el tueste igual que el POST. Si `new_out < withdrawn_kg(...)` → `ApiError(409, "insufficient_roasted_stock", "roasted_out_kg es menor que lo ya retirado")`. Después de `commit`, ejecuta `db.refresh(roast)` para que `roasted_stock_kg` salga actualizado. Haz lo mismo en `create_roast`, que ya llama a `refresh`.
- [ ] **Paso 4:** `cd api && pytest -v` → todo PASA, incluidos `test_roasts.py` y `test_green_lots.py` (sus respuestas ya traen `roasted_stock_kg`).
- [ ] **Paso 5:** commit `feat(api): salidas de café tostado por tueste`.

### Task 3: Frontend

**Archivos:**
- Modificar: `web/lib/models.dart`, `web/lib/roast_detail_screen.dart`, `web/lib/roasts_screen.dart`
- Crear: `web/lib/withdrawals.dart`, `web/test/withdrawals_test.dart`

**Interfaces:**
- Consume: el JSON de la tarea 2.
- Produce:
  - En `models.dart`: `Roast.roastedStockKg: double`; `class Withdrawal` (`id`, `userName`, `withdrawnAt: DateTime`, `kg: double`, `reason`, `notes?`); `RoastDetail.withdrawals: List<Withdrawal>`; `const withdrawalReasons = {'sale': 'Venta', 'consumption': 'Consumo', 'other': 'Otro'}`.
  - En `withdrawals.dart`:
    - `List<FieldSpec> withdrawalFields`: `kg` decimal "Kg", `reason` select "Motivo", `withdrawn_at` datetime "Fecha y hora", `notes` multiline opcional "Notas".
    - `Future<void> submitWithdrawal(Api api, String roastId, double available, Map<String, dynamic> v)`: si `v['kg'] > available + 1e-9`, lanza `Exception('Stock tostado disponible: ${fmtKg(available)}')` sin llamar a la API. Si no, hace `POST /roasts/$roastId/withdrawals`. El margen de `1e-9` es para el punto 5.
    - `Future<void> registerWithdrawal(BuildContext, WidgetRef, Roast)`: abre `showEditDialog` con título "Registrar salida", `initial` con `withdrawn_at` = ahora (formato `yyyy-MM-dd HH:mm`) y `reason: 'sale'`, y un `footer` que muestra "Disponible: X kg". Al guardar invalida `roastProvider`, `roastsProvider` y `lotProvider`.
    - `class WithdrawalList extends StatelessWidget` (`withdrawals`, `isAdmin`, `onDelete: void Function(Withdrawal)`): cada fila muestra fecha, kg, motivo en español, `userName` y notas. El `IconButton` de borrar (tooltip "Eliminar salida") aparece solo si `isAdmin`. Sin salidas, muestra "Sin salidas".
  - `api.dart` no cambia: `roast()` ya devuelve el detalle y `send()` cubre POST y DELETE.

- [ ] **Paso 1: tests que fallan** en `withdrawals_test.dart`:
  - `WithdrawalList` con una salida y `isAdmin: false` → `find.byTooltip('Eliminar salida')` no encuentra nada. Con `isAdmin: true` → la encuentra una vez. También muestra "Venta".
  - Diálogo con `withdrawalFields`, un `footer` y un `onSubmit` que llama a `submitWithdrawal` con un `Api` falso (o un `onSubmit` que replica la regla) y `available: 2.5`: con `2,6` aparece "Stock tostado disponible: 2,5 kg" y el diálogo sigue abierto. Con `2,5` se cierra. (Punto 5)
- [ ] **Paso 2:** `cd web && flutter test test/withdrawals_test.dart` → FALLA.
- [ ] **Paso 3:** implementa `models.dart` y `withdrawals.dart`. Si probar `submitWithdrawal` con un `Api` real resulta difícil, separa la regla en `String? exceedsStock(double? kg, double available)` y prueba esa función. Elige una de las dos opciones.
- [ ] **Paso 4:** en `roast_detail_screen.dart`, debajo de la merma, agrega la fila "Stock tostado `fmtKg(r.roastedStockKg)`". Antes del lote de origen, agrega la sección "Salidas" con el botón "Registrar salida" y `WithdrawalList`. `onDelete` usa `confirm` y `DELETE`, igual que el borrado de tueste.
- [ ] **Paso 5:** en `roasts_screen.dart`, agrega la columna "Stock tostado" después de "Salida", con su celda `m(fmtKg(r.roastedStockKg))`. Suma ` · stock X` al subtítulo de la tarjeta.
- [ ] **Paso 6:** `cd web && flutter analyze && flutter test` → sin problemas y todo PASA.
- [ ] **Paso 7:** commit `feat(web): stock tostado y registro de salidas en el detalle del tueste`.

### Task 4: Cierre

- [ ] `cd api && pytest`, `cd web && flutter analyze && flutter test`.
- [ ] `docker compose up --build -d`: `api` queda sano (`/api/v1/health`), la migración `0002` se aplica al arrancar y http://localhost:8081 carga. Registra una salida a mano y comprueba que el stock baja.
- [ ] Escribe `specs/007-salidas-de-tostado/dev-notes.md` con las decisiones del developer (por ejemplo, la opción elegida en el paso 3 de la tarea 3).
- [ ] Commit `docs: notas de desarrollo 007`.
- [ ] Siguiente en el flujo: `security` → `qa` → `product-owner`.
