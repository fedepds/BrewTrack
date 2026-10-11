# 001 — Notas de desarrollo

## Desvíos del plan
- `web/lib/api.dart`: `{'month': ?month}` en lugar de `{if (month != null) 'month': month}`. El lint `use_null_aware_elements` pide esa forma; el comportamiento es igual (Dart 3.8+, el proyecto pide ^3.12).

## Entorno usado para verificar
- `api/.venv` apunta a `~/Desktop/3` y no funciona. Las pruebas de la API corrieron con un venv temporal fuera del repo. Conviene rehacer `api/.venv`.
- Flutter no está instalado en el host. `flutter test` y `flutter analyze` corrieron en `ghcr.io/cirruslabs/flutter:stable`, la misma imagen del `Containerfile`, sobre una copia de `web/`. Así `pubspec.lock` no cambia.
- El puerto 8080 lo ocupa el stack de `~/Desktop/3`. El stack se validó publicando `web` en 8081 con un override temporal.

## Resultados
- `flutter analyze`: sin problemas.
- `pytest`: 68 pruebas pasan (21 nuevas en `tests/test_stats.py`).
- `flutter test`: 15 pruebas pasan.
- Stack: `api` sano. `/api/v1/health` responde `{"status":"ok"}`, la web responde 200, `/api/v1/stats/summary` sin token responde 401 con `{"error": {...}}` y figura en el OpenAPI. La imagen de la API trae la base de zonas horarias (`zoneinfo` resuelve `America/Argentina/Buenos_Aires`).
- No se probó la pantalla con sesión iniciada en el stack: la base del stack no tiene usuarios. Las pruebas de widgets y de API contra Postgres cubren ese camino.

## Pendientes menores (no bloquean)
- La pantalla no refresca el "mes actual" si queda abierta durante un cambio de mes.
- Las tarjetas miden 240 px de ancho fijo y desbordan en pantallas de menos de unos 272 px.
- Ninguna prueba verifica que `Api.summary` omite `month` cuando es null, ni que tocar "Resumen" navega a `/stats`.
- La prueba de 422 no comprueba que `error` tenga exactamente `code` y `message`.
