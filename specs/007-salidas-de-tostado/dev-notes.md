# Notas del developer — 007 Salidas de café tostado

## Qué cambió

- **Datos (`1928719`).** Tabla `roast_withdrawals` con migración `0002`, y helper del stock tostado en `app/stock.py`. El stock tostado no se guarda: es `roasted_out_kg` menos la suma de `kg` de las salidas.
- **API (`39b5202`).** `GET` y `POST /roasts/{id}/withdrawals`, `DELETE /roasts/{id}/withdrawals/{withdrawal_id}` (solo admin). `RoastOut` y `RoastDetail` llevan `roasted_stock_kg`; `RoastDetail` lleva también las salidas. Borrar un tueste con salidas y bajar `roasted_out_kg` por debajo de lo retirado dan 409. La validación bloquea la fila del tueste con `FOR UPDATE`.
- **Web (`1763e9c`).** Stock tostado y lista de salidas en el detalle del tueste, diálogo **Registrar salida**, columna "Stock tostado" en tabla y tarjetas, borrar solo para admin. `models.dart` y `api.dart` al día.
- **Limpieza.** Quité la clave `roasted_stock_kg` del fixture de `Summary` en `stats_screen_test.dart` (`Summary` no tiene ese campo) y ordené los imports de `api/tests/test_models.py`.

## Decisiones del developer

- **Prueba de `submitWithdrawal`.** Usa un `Api` real sobre un adaptador Dio falso. No hay función `exceedsStock` aparte: el tope de stock lo impone el validador del campo, y la API devuelve el 409.
- **`_StockException` privada.** El diálogo muestra el mensaje del backend sin el prefijo "Exception: ".
- **`ResponsiveTable` con scroll horizontal** (`web/lib/widgets.dart`). La octava columna desbordaba el ancho.
- **404.** El mensaje es "Salida no encontrada".

## Cómo probarlo

- `cd api && pytest` (Postgres de pruebas en el puerto 55432).
- `cd web && flutter analyze && flutter test`.
- Stack: `docker compose up --build -d`; `api` sano en `/api/v1/health`; http://localhost:8081 carga; la migración `0002` aplica al arrancar.

## Preguntas abiertas

Ninguna.

## Pendiente

- Seguridad (Semgrep y Trivy), luego QA y product-owner.
- La constitución (diseño y `AGENTS.md`) ya incluye `roast_withdrawals` y la regla del stock tostado desde el commit `23ee6c2`.
