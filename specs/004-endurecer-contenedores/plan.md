# Plan 004 — Endurecer el contenedor web y el secreto JWT

## Diseño técnico

**Web sin root (RF-1 a RF-6).** La etapa final sigue en `nginx:alpine`. Se añade `USER nginx` y nginx escucha en 8080 (puerto sin privilegios). Para que arranque sin root:
- `sed` quita `user nginx;` de `nginx.conf` y mueve el pid a `/tmp/nginx.pid`.
- `chown` a `nginx` de `/var/cache/nginx` y de `/etc/nginx/conf.d`, donde el entrypoint genera `default.conf` desde la plantilla.
- `compose.yaml` mapea `8080:8080`; el host sigue en 8080.
El proxy y el `resolver` no cambian, así que RF-4 y RF-5 se mantienen.

**Secreto JWT (RF-7 a RF-11).** `field_validator("jwt_secret")` en `Settings` rechaza menos de 32 caracteres y el valor de la plantilla. Los mensajes no incluyen el valor. `_load()` captura `ValidationError` y termina con `SystemExit` y un mensaje en español, construido con `errors(include_input=False)`. Así no sale `input_value` ni traza.

## API y pantallas
Sin cambios de endpoints, modelos Dart ni pantallas. Sin cambios de datos ni migraciones.

## Constitución

| Regla | Cómo la cumple este cambio |
|---|---|
| Alcance | Solo endurece `web` y la configuración de la API. Sin funciones nuevas. |
| Stock | No toca cálculos ni datos. |
| Permisos en la API | Sin cambios; el proxy solo reenvía (probado con 401 sin token y 200 con token). |
| Errores | Los errores HTTP siguen en `{"error": {...}}`. El fallo de arranque no es HTTP. |
| Esquema | Sin cambios, sin migración. |
| Secretos | `JWT_SECRET` entra por entorno; ninguna salida lo muestra; `.env` no se lee. |
| Imagen runtime | `nginx:alpine` (D-1). |
