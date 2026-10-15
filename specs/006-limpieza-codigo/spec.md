# 006 — Limpieza de código

Estado: aceptada
Fecha: 2026-10-15

## Contexto y objetivo

Una auditoría de sobreingeniería revisó todo el repositorio. Encontró restos de plantillas, código que nadie usa y un mismo cálculo repetido en varios sitios. Nada de esto falla hoy, pero cada copia es un sitio más donde un cambio futuro puede olvidarse.

Objetivo: borrar lo que sobra y quitar las copias. La API lee el stock con una sola expresión (RF-8). La persona usuaria no nota ningún cambio: la API responde igual, la web se ve y se comporta igual, y el alcance no cambia.

Hallazgos que cubre esta spec:
1. `web/pubspec.yaml` trae unas 70 líneas de comentarios de la plantilla de Flutter y la dependencia `cupertino_icons`, que nadie usa.
2. `web/README.md` es el README de la plantilla de Flutter.
3. La API asigna `stock_kg` a mano en cuatro sitios (`_with_stock` y `list_lots` en `api/app/routers/green_lots.py`, `create_lot` en el mismo archivo y `get_roast` en `api/app/routers/roasts.py`). `api/app/stock.py` tiene dos sumas casi iguales (`used_expr` y `used_kg`), y `api/app/routers/stats.py` usa una de ellas.
4. Nadie lee la clase `Paged<T>` de `web/lib/models.dart` ni su campo `total`.
5. `web/docker-entrypoint.d/10-api-host.envsh` existe solo para dar a `API_HOST` el valor `api` por defecto.
6. `api/app/config.py` permite fijar por entorno `access_ttl_min` y `refresh_ttl_days`. Nadie lo hace, y la constitución fija 1 h y 7 días.

Propuesta de la auditoría para el punto 3, que el developer puede seguir o cambiar: definir el stock una vez en el modelo del lote, como diferencia entre `received_kg` y la suma de `green_in_kg` de sus tuestes, calculada en cada lectura. `used_kg(..., exclude)` queda solo para validar que un tueste no supera el stock. El riesgo: tras una escritura, el valor leído puede quedar viejo. Por eso RF-6 y CA-3 a CA-10 piden el stock correcto después de cada escritura.

## Historias de usuario

- HU-1. Como `admin`, que también mantiene el sistema, quiero que la API lea el stock con una sola expresión, para que un cambio en la regla no deje respuestas con valores distintos.
- HU-2. Como `admin`, quiero que el repositorio no traiga código ni archivos que nadie usa, para leer y revisar menos.
- HU-3. Como `roaster`, quiero que la API y la web sigan igual tras la limpieza, para seguir trabajando sin aprender nada nuevo.

## Requisitos funcionales

Comportamiento
- RF-1. Ningún endpoint cambia: rutas, métodos, permisos, cuerpos, respuestas, códigos de estado y errores siguen iguales. `/api/v1/openapi.json` no cambia.
- RF-2. La web no cambia lo que muestra ni lo que permite hacer a cada rol.

Stock en la API
- RF-3. La API lee el stock de un lote con una sola expresión (RF-8). Ninguna ruta ni `stats.py` lo calcula ni lo asigna por su cuenta. La validación antes de escribir usa su propia suma (RF-8).
- RF-4. El stock sigue sin guardarse: no hay columna ni valor almacenado. Siempre es `received_kg` menos la suma de `green_in_kg` de los tuestes del lote.
- RF-5. Todas las respuestas que hoy llevan `stock_kg` lo siguen llevando con el mismo valor y formato: listado de lotes, detalle de lote, alta y edición de lote, detalle de tueste (dentro del lote de origen) y `GET /api/v1/stats/summary` (`lots_in_stock` y `stock_kg`).
- RF-6. Tras cualquier escritura (crear o editar un lote; crear, editar o borrar un tueste), la siguiente lectura y la respuesta de la propia escritura, si lleva `stock_kg`, muestran el stock actual. Nunca un valor anterior a la escritura.
- RF-7. La validación de stock no cambia: un tueste nuevo o editado no puede superar el stock disponible del lote, y un lote no puede bajar `received_kg` por debajo de lo ya tostado. Los códigos y mensajes de error siguen iguales.
- RF-8. La API tiene una sola expresión para leer el stock: `GreenLot.stock_kg` en `api/app/models.py`. `used_kg(..., exclude)` sigue en `api/app/stock.py`, solo para validar antes de escribir. No se deriva de `GreenLot.stock_kg` por dos motivos: al editar un tueste, la validación excluye ese tueste; y `seed_roasts` valida entre un `flush` y el siguiente sobre lotes ya cargados, cuyo `stock_kg` estaría viejo. `used_expr` desaparece.

Tokens
- RF-9. La duración del token de acceso (60 min) y del refresh token (7 días) pasan a ser valores fijos del código de la API. No se leen del entorno. `api/app/config.py` ya no los define.

Frontend
- RF-10. `web/pubspec.yaml` no trae los comentarios de la plantilla de Flutter ni la dependencia `cupertino_icons`. Conserva todo lo demás, incluida la opción que carga los iconos de Material. `web/pubspec.lock` se regenera con `flutter pub get`.
- RF-11. `web/README.md` desaparece, o queda con una sola línea que apunta al `README.md` de la raíz.
- RF-12. La clase `Paged<T>` desaparece. Los listados de lotes y tuestes del cliente devuelven la lista de elementos. Providers y pantallas la usan sin cambios visibles. La API sigue enviando `total`; el cliente solo deja de leerlo.

Imagen `web`
- RF-13. La imagen `web` da a `API_HOST` el valor `api` por defecto desde `web/brewtrack-web.Containerfile`. El script `web/docker-entrypoint.d/10-api-host.envsh` y la línea que lo copia desaparecen. Este requisito cambia a propósito el CA-3 de la spec 004, que decía que la imagen `web` no define `API_HOST`. Ahora la imagen lo define con `ENV API_HOST=api`. La spec 004 no se edita.
- RF-14. Un valor de `API_HOST` dado al contenedor sigue mandando sobre el valor por defecto. `k8s/brewtrack.yaml` no cambia.
- RF-15. `k8s/README.md` sigue describiendo bien `API_HOST`. Si su texto (cerca de la línea 147) nombra el script, se corrige.
- RF-16. Si la imagen `web` cambia de etiqueta, cambia a la vez en `compose.yaml` y en `k8s/brewtrack.yaml`. El developer propone el valor.

Pruebas
- RF-17. Los tests de API cubren el stock en cada lectura y tras cada escritura de RF-5 y RF-6 (CA-3 a CA-11).
- RF-18. Ningún test existente se borra ni se debilita, salvo los que solo prueban código borrado por esta spec. El developer los nombra en `dev-notes.md`.

## Criterios de aceptación

Contrato y regresión:
- CA-1. Dado el `openapi.json` de la rama `feat/005-monitoreo` (commit `e4731a6`) y el de esta rama, cuando se comparan, entonces son iguales. No se compara con `master`, que todavía no tiene la spec 005.
- CA-2. Dado el repositorio, cuando se corren `cd api && pytest`, `cd web && flutter analyze` y `cd web && flutter test`, entonces los tres terminan con código 0 y `flutter analyze` no reporta avisos.

Stock (pytest, con un lote de `received_kg` 100):
- CA-3. Dado el lote sin tuestes, cuando se pide `GET /api/v1/green-lots`, entonces el lote sale con `stock_kg` 100.
- CA-4. Dado `POST /api/v1/green-lots` con `received_kg` 100, cuando responde 201, entonces la respuesta trae `stock_kg` 100.
- CA-5. Dado el lote, cuando se crea un tueste con `green_in_kg` 30, entonces `GET /api/v1/green-lots/{id}` y el listado dan `stock_kg` 70.
- CA-6. Dado CA-5, cuando se pide `GET /api/v1/roasts/{id}` del tueste, entonces el lote de origen trae `stock_kg` 70.
- CA-7. Dado CA-5, cuando se edita el tueste a `green_in_kg` 40, entonces el detalle del lote, el listado y el detalle del tueste dan `stock_kg` 60.
- CA-8. Dado CA-7, cuando un `admin` borra el tueste, entonces el detalle del lote y el listado dan `stock_kg` 100.
- CA-9. Dado el lote con un tueste de 30 kg, cuando se hace `PATCH /api/v1/green-lots/{id}` con `received_kg` 120, entonces la respuesta del `PATCH` y el detalle del lote dan `stock_kg` 90.
- CA-10. Dado el lote con un tueste de 30 kg, cuando se hace `PATCH` del lote sin tocar `received_kg` (por ejemplo, solo `notes`), entonces la respuesta da `stock_kg` 70.
- CA-11. Dados dos lotes con tuestes, cuando se pide `GET /api/v1/stats/summary`, entonces `lots_in_stock` y `stock_kg` coinciden con la suma de los `stock_kg` del listado. Los tests de `test_stats.py` siguen pasando sin cambios.
- CA-12. Dado un lote con 70 kg de stock, cuando se crea un tueste de 71 kg, o se edita uno para pasar el stock, entonces la API responde con el mismo código y el mismo `{"error": {"code", "message"}}` que en `master`, y el stock no cambia.
- CA-13. Dado el código de la API, cuando se busca en `api/app/routers/` una asignación al atributo `stock_kg` de un objeto (`.stock_kg =`), entonces no aparece ninguna. El argumento con nombre `stock_kg=` con que `stats.py` arma la respuesta del resumen no cuenta: es un campo del contrato (RF-1), no el stock de un lote.

Tokens:
- CA-14. Dado un login correcto, cuando se decodifica el token de acceso, entonces `exp` menos `iat` es 3600 s. En el refresh token es 604 800 s.
- CA-15. Dado `api/app/config.py`, cuando se busca `ttl`, entonces no aparece.

Frontend:
- CA-16. Dado `web/pubspec.yaml`, cuando se busca `cupertino` o una línea de comentario de la plantilla, entonces no aparece ninguna. `web/pubspec.lock` no nombra `cupertino_icons`.
- CA-17. Dado `web/README.md`, entonces no existe o tiene una sola línea con un enlace al `README.md` raíz.
- CA-18. Dado `web/lib` y `web/test`, cuando se busca `Paged`, entonces no aparece.
- CA-19. Dados los tests de widgets actuales de las pantallas de lotes y tuestes, cuando corren, entonces pasan sin cambiar lo que comprueban.

Imagen y stack:
- CA-20. Dado el repositorio, entonces `web/docker-entrypoint.d/10-api-host.envsh` no existe y ningún archivo fuera de `specs/` lo nombra. Las specs anteriores, como la 004, lo nombran como historia y no se editan.
- CA-21. Dado `podman compose up --build -d`, cuando el stack arranca, entonces `api` queda sano, `GET http://localhost:8081/api/v1/health` responde 200 (el proxy de nginx llega a la API) y `http://localhost:8081` carga la web.
- CA-22. Dado CA-21, cuando un `admin` entra a la web, entonces ve el listado de lotes con su stock y abre el detalle de un lote sin errores.
- CA-23. Dada la imagen `web`, cuando se arranca el contenedor con `API_HOST=otrohost`, entonces la configuración de nginx generada apunta a `otrohost:8000`. Sin la variable, apunta a `api:8000`.
- CA-24. Dado `k8s/`, cuando se corre `kubectl apply --dry-run=client -f k8s/`, entonces termina con código 0. Si cambió la etiqueta de `web`, es la misma en `compose.yaml` y en `k8s/brewtrack.yaml`.

## Chequeo de constitución

- **Alcance:** aplica. Solo limpia código de lotes, tuestes, auth y del cliente web. No suma nada; no toca curvas, empaque, venta, recetas, cata ni multi-empresa.
- **Stock calculado:** aplica. La API lee el stock con una sola expresión, que calcula en cada lectura; la validación antes de escribir usa su propia suma (RF-8). Nunca se guarda (RF-4). RF-6 y CA-3 a CA-11 exigen el valor correcto tras cada escritura.
- **Permisos en la API:** aplica. Ningún permiso cambia (RF-1). Los tests de roles actuales siguen pasando (CA-2).
- **Formato de error:** aplica. Los errores siguen con `{"error": {"code", "message"}}` y los mismos códigos (RF-7, CA-12).
- **Migraciones:** no aplica. El esquema no cambia: el stock no pasa a ser columna.
- **Secretos:** aplica. La duración de los tokens deja de leerse del entorno, pero no es un secreto. `JWT_SECRET` sigue entrando por variable de entorno. Nadie lee ni toca `.env`.

## Fuera de alcance

Elementos que la auditoría revisó y se quedan, porque una spec los exige:
- `_init_denied_series` en `api/app/metrics.py`: la pide RF-11 de la spec 005.
- `_guarded` en `seed.py`: protege la carga de lotes de ejemplo de la spec 002.
- `commit_or_409`: da el 409 de código de lote repetido.
- La validación extra en `RoastPatch`: impide que un tueste editado quede con `roasted_out_kg` mayor que `green_in_kg`.
- La guarda del entrypoint de Grafana: la pide RF-17 de la spec 005.
- El `Kind` de `web/lib/edit_dialog.dart`: lo usan los formularios de alta y edición.

Otros:
- Unir `AccessOut` con `Tokens` en `api/app/routers/auth.py` (ver PA-1).
- Cambiar el contrato de la API, la paginación o el campo `total` que envía.
- Mejoras de rendimiento de las consultas.
- Tests nuevos de widgets: no cambia lo que la web muestra.

## Preguntas abiertas

- PA-1 (cerrada por el PO). ¿Se cambia `AccessOut` por `Tokens` con `refresh_token` opcional? No. Ahorra unas tres líneas, pero cambia el contrato de `/auth/refresh` y debilita el de `/auth/login`: el OpenAPI diría que `refresh_token` puede faltar en el login, cuando siempre viene. Obliga también a tocar los modelos Dart. Esta spec promete no cambiar ningún endpoint (RF-1), y el ahorro no lo justifica.

## Historial

| Fecha | Versión | Cambio |
|---|---|---|
| 2026-10-15 | 1.0 | Versión inicial, a partir de la auditoría de sobreingeniería. El PO deja fuera la unión de `AccessOut` y `Tokens` (PA-1) y suma `GET /api/v1/stats/summary` a las lecturas de stock que se prueban, porque también usa la suma que se unifica. Estado: borrador. |
| 2026-10-15 | 1.1 | Cambios tras el plan del developer. RF-8: una sola expresión para leer el stock (`GreenLot.stock_kg`); `used_kg(..., exclude)` se queda solo para validar antes de escribir, porque la validación excluye el tueste que se edita y `seed_roasts` valida entre `flush` y `flush`. RF-3 se ajusta a RF-8. CA-20: la búsqueda de `10-api-host.envsh` excluye `specs/`. RF-13: anota que cambia a propósito el CA-3 de la spec 004 (la imagen `web` ahora define `API_HOST`); la 004 no se edita. CA-1: el `openapi.json` de referencia es el de `feat/005-monitoreo`, no el de `master`. Estado: aprobada. |
| 2026-10-15 | 1.2 | La spec 007 absorbe el punto 5 (`10-api-host.envsh`): esta spec deja RF-13 a RF-16, CA-20, CA-23 y la frase sobre la etiqueta de `web` en CA-24. En "Fuera de alcance" quedan viejas las líneas de `_init_denied_series` y de la guarda del entrypoint de Grafana: la 007 las quita. Detalle en `specs/007-simplificar-infra/spec.md`. |
| 2026-10-15 | 1.3 | Aceptada, según el informe de QA (aprobado con observaciones, sin fallos). Cumplen CA-1 a CA-19, CA-21 y CA-22. No se piden cambios al developer. Decisiones del PO: (1) CA-24 queda sin efecto en esta spec: tras la 1.2 solo pide el dry-run de `k8s/`, y lo que queda de la 006 no toca `k8s/`; la 007 lo pide en su propio CA-24 sobre los manifiestos finales. La etiqueta `0.1.2` y lo que QA comprobó de CA-20 y CA-23 pertenecen al punto 5, que la 007 sustituye. (2) CA-13 se precisa: busca asignaciones al atributo `stock_kg` de un objeto; el argumento `stock_kg=` del resumen en `stats.py` es un campo del contrato y cumple. Se acepta renombrar la variable local de `stats.py` a `stock_total`: no cambia el comportamiento. (3) `db.refresh(lot)` en `create_lot` y `patch_lot` se queda. La spec pide el resultado (RF-6), no el medio, y CA-9 y CA-10 fallan si un cambio futuro deja el stock viejo en la respuesta. (4) CA-12 cumple con la edición a 101 sobre un lote de 100: el texto pide "editar para pasar el stock", sin cifra, y ese caso prueba la exclusión del propio tueste (RF-8). (5) CA-22 se acepta por el proxy, sin navegador: la API da los mismos datos que leen las pantallas, la web carga (CA-21) y los tests de widgets de lotes y tuestes pasan sin cambios (CA-19). Se alinean con RF-8 las frases de "un solo sitio" del contexto, de HU-1 y del chequeo de constitución, y el chequeo de alcance deja de nombrar la imagen `web`. |
