# 007 — Salidas de café tostado

Estado: aprobada
Fecha: 2026-11-14

## Contexto y objetivo

BrewTrack controla el stock de café verde, pero no el del tostado. Cada tueste produce `roasted_out_kg`, y después nadie registra qué pasa con esos kilos. Lo que el taller vende es café tostado.

El usuario quiere registrar en la base cada vez que sale café tostado, sea por venta o por consumo, para saber cuánto queda de cada tueste y de dónde salió cada venta.

Objetivo: cada tueste muestra su stock tostado. Ambos roles registran salidas contra un tueste concreto, y la API impide sacar más de lo que hay.

## Decisiones

- D-1. Las salidas se registran contra un **tueste concreto**, no contra un lote ni un producto, para mantener la trazabilidad lote → tueste → salida. (Elegida por el usuario.)
- D-2. Las salidas viven en una **tabla nueva**, `roast_withdrawals`. Descartamos una tabla única de movimientos para verde y tostado, porque obliga a claves foráneas con nulos y cambia la fórmula del stock verde. También descartamos guardar el stock tostado en `roasts`, porque rompe la regla de que el stock nunca se guarda. (Elegida por el usuario.)
- D-3. La **entrada** de stock tostado es el propio tueste (`roasted_out_kg`). No hay entradas manuales.
- D-4. Una **venta** es una salida con motivo `sale`. No registra precio, cliente ni factura. Empaque y venta siguen fuera del alcance.
- D-5. Una compra nueva de café verde se registra como un lote nuevo. Esta spec no suma kilos a lotes existentes. (Propuesta de Claude.)
- D-6. Las salidas no se editan. Para corregir un error, el admin borra la salida y se carga de nuevo. (Propuesta de Claude.)

## Cambio en la constitución

Al aprobar esta spec se actualiza `docs/superpowers/specs/2026-10-07-brewtrack-design.md` y el resumen de `AGENTS.md`:

- Alcance, dentro: "Salidas de café tostado por tueste (venta, consumo, otro), sin precios ni clientes."
- Alcance, fuera: "Empaque y venta" pasa a "Empaque, precios, clientes y facturación".
- Modelo de datos: se agrega `roast_withdrawals`.
- Stock: "El stock tostado de un tueste tampoco se guarda: es `roasted_out_kg` menos la suma de `kg` de sus salidas."

## Historias de usuario

- HU-1. Como `roaster` o `admin`, quiero registrar que salieron X kg de un tueste, con motivo y fecha, para saber cuánto queda.
- HU-2. Como `roaster` o `admin`, quiero ver el stock tostado y el historial de salidas de cada tueste.
- HU-3. Como `admin`, quiero borrar una salida mal cargada.

## Requisitos funcionales

### Datos

- RF-1. Tabla `roast_withdrawals` con `id` UUID, `created_at`, `updated_at`, y:
  - `roast_id` → `roasts` (`ON DELETE RESTRICT`), con índice;
  - `user_id` → `users` (quién la registró, lo pone la API desde el token);
  - `withdrawn_at` (fecha y hora, con zona);
  - `kg` `Numeric(10, 3)`, constraint `kg > 0`;
  - `reason` `sale` | `consumption` | `other`, con constraint en la base;
  - `notes` opcional.
- RF-2. Migración Alembic nueva. No se edita ninguna migración aplicada.

### API

- RF-3. `GET /roasts/{id}/withdrawals`: lista las salidas del tueste, de la más nueva a la más vieja. Ambos roles.
- RF-4. `POST /roasts/{id}/withdrawals`: crea una salida. Ambos roles. Responde 404 si el tueste no existe, 422 si los datos son inválidos y 409 `insufficient_roasted_stock` si `kg` supera el stock tostado disponible, con el disponible en el mensaje.
- RF-5. `DELETE /roasts/{id}/withdrawals/{withdrawal_id}`: solo admin (403 para `roaster`). Responde 404 si la salida no existe o no pertenece a ese tueste.
- RF-6. `RoastOut` y `RoastDetail` agregan `roasted_stock_kg` (calculado). `RoastDetail` agrega también la lista de salidas.
- RF-7. Borrar un tueste con salidas responde 409.
- RF-8. Si un `PATCH` de tueste baja `roasted_out_kg` por debajo de lo ya retirado, responde 409.
- RF-9. Para evitar que dos salidas simultáneas superen el stock, la validación bloquea la fila del tueste (`SELECT … FOR UPDATE`), igual que hoy se bloquea el lote.

### Frontend

- RF-10. El detalle del tueste muestra el stock tostado, la lista de salidas (fecha, kg, motivo, quién, notas) y el botón **Registrar salida**.
- RF-11. El formulario de salida pide kg, motivo (Venta, Consumo, Otro), fecha (por defecto, ahora) y notas. Muestra el stock disponible y no deja enviar más de eso. Los 409 y 422 se muestran con el mensaje del backend.
- RF-12. La tabla y las tarjetas de tuestes agregan la columna "Stock tostado".
- RF-13. El botón de borrar una salida solo aparece para el admin.
- RF-14. Se actualizan a mano `web/lib/models.dart` y `web/lib/api.dart`.

## Fuera de alcance

- Precios, clientes, facturas, empaques o productos.
- Entradas manuales de tostado, por ejemplo café comprado ya tostado.
- Sumar kilos a un lote verde existente.
- Editar salidas.

## Pruebas

- API: auth y roles (los dos roles crean, solo admin borra), stock tostado calculado, salida que supera el stock (409), borrado de tueste con salidas (409), `PATCH` de `roasted_out_kg` por debajo de lo retirado (409), constraints de `kg` y `reason`.
- Widgets: el formulario de salida no deja pasar del stock disponible, y el botón de borrar se ve solo para el admin.

## Queda a criterio del developer

- Nombres internos, la ubicación del helper de stock tostado (por ejemplo, en `app/stock.py`) y el diseño exacto del diálogo, siguiendo los existentes (`edit_dialog.dart`).
