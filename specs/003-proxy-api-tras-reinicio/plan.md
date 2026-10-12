# 003 — Plan

Spec: `spec.md` v1.0. Sin cambios de esquema, API ni Flutter.

## Constitución

| Regla | Cómo la cumple este cambio |
|---|---|
| Alcance | Solo corrige el proxy de nginx. |
| Stock calculado | No toca cálculos. |
| Permisos en la API | El proxy solo reenvía; la API sigue imponiéndolos (CA-4). |
| Formato de error | Los errores de la API llegan sin cambios (CA-4). |
| Esquema | No cambia, no hay migración. |
| Secretos | No entra ninguna variable secreta. |

## Diseño

- `web/nginx.conf` pasa a `web/templates/default.conf.template`. La imagen `nginx:alpine` ejecuta `envsubst` sobre `/etc/nginx/templates` al arrancar.
- `web/Containerfile`: `ENV NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1` hace que el entrypoint lea el `nameserver` de `/etc/resolv.conf` en `NGINX_LOCAL_RESOLVERS`. Así no se fija ninguna IP (RF-3).
- En `location /api/`: `resolver ${NGINX_LOCAL_RESOLVERS} valid=5s;`, `set $api_upstream http://api:8000;` y `proxy_pass $api_upstream;`. Con variable, nginx resuelve `api` otra vez al vencer el TTL (RF-1).
- `proxy_pass` sigue sin ruta, así que nginx reenvía la URI original con su query (RF-2, CA-3). Cabeceras y `location /` no cambian (RF-4).

## Pruebas

Manuales, en un stack aparte (ver `dev-notes.md`). No hay prueba automática del stack (fuera de alcance).
