# Tareas 007

1. Modelo `RoastWithdrawal`, migración `0002`, `Roast.roasted_stock_kg` y `withdrawn_kg`, con tests de modelo. (RF-1, RF-2)
2. Endpoints `GET/POST/DELETE /roasts/{id}/withdrawals`, `roasted_stock_kg` y `withdrawals` en las respuestas, 409 al borrar un tueste con salidas y 409 al bajar `roasted_out_kg`, con bloqueo del tueste y tests. (RF-3 a RF-9)
3. Frontend: modelos Dart, `withdrawals.dart` (formulario, regla de stock, lista), detalle del tueste y columna "Stock tostado", con tests de widgets. (RF-10 a RF-14)
4. Cierre: `pytest`, `flutter analyze`, `flutter test`, stack local y `dev-notes.md`.
