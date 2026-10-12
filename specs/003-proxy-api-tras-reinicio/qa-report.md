# 003 — Informe de QA

Veredicto: **APROBADO**

Spec v1.0, rama `fix/003-proxy-api-tras-reinicio`, commit fbf4b14. Ningún CA falla.

## Ejecución

| Comando | Resultado |
|---|---|
| `cd api && pytest` | 96 pasan |
| `cd web && flutter analyze` | Sin problemas |
| `cd web && flutter test` | 15 pasan |
| Stack `bt003qa` (puerto 8094, volumen nuevo, env temporal) | `db`, `api` sanos; web 200. Borrados proyecto, volumen, imágenes y archivos. No toqué `brewtrack2` ni el 8080. |

## Criterios de aceptación

| CA | Evidencia | Resultado |
|---|---|---|
| CA-1 | `podman compose restart api` sin tocar `web`: `/api/v1/health` por `web` dio 200 al 2.º intento (unos 2 s) | Pasa |
| CA-2 | Dos reinicios más: 200 al 2.º intento cada vez | Pasa |
| CA-3 | Con sesión, `GET /api/v1/green-lots?limit=5&offset=0` por `web`: `limit` 5, `offset` 0, 5 elementos; el log de la API muestra la query intacta | Pasa |
| CA-4 | Sin token: 401 `{"error":{"code":"unauthorized","message":"Credenciales inválidas o ausentes"}}` | Pasa |
| CA-5 | `/lotes` y `/` dan 200 con el `index.html` de Flutter | Pasa |
| CA-6 | `pytest`, `flutter analyze` y `flutter test` como arriba | Pasa |

RF-3: dentro de `web`, `/etc/resolv.conf` tiene `nameserver 10.89.11.1` y `default.conf` generado tiene `resolver 10.89.11.1 valid=5s;`. La plantilla toma el DNS de la red, no una IP fija.

## Comparación con el `nginx.conf` borrado

El `server` es igual salvo `resolver`, `set $api_upstream` y `proxy_pass $api_upstream`. Se conservan `listen 80`, `root`, `index`, `Host`, `X-Forwarded-For` y `try_files $uri $uri/ /index.html`. Sin ruta en `proxy_pass` con variable, nginx reenvía la URI original con su query; CA-3 lo confirma. No comprobé las cabeceras `Host` y `X-Forwarded-For` en la API; la revisión del diff las muestra sin cambio.

## Referencias a `web/nginx.conf`

Ninguna viva: ni `web/Containerfile`, ni `compose.yaml`, ni `.containerignore`, ni `README.md`. Quedan menciones históricas en `docs/superpowers/specs/2026-10-07-brewtrack-design.md` (línea 93, árbol de carpetas) y `docs/superpowers/plans/2026-10-07-brewtrack.md`. Son documentos de diseño; el árbol de la constitución queda desactualizado. Severidad baja; la constitución la cambia una persona.

## Constitución

| Regla | Resultado | Evidencia |
|---|---|---|
| Alcance | Cumple | Solo cambia el proxy de `web`. |
| Stock calculado, sin columna | No aplica | Sin cambios en `models.py` ni migraciones. |
| Permisos en la API | Cumple | 401 sin token pasa por el proxy (CA-4). |
| Errores `{"error": {"code", "message"}}` | Cumple | CA-4. |
| Migración nueva | No aplica | Sin cambio de esquema. |
| Sin credenciales ni `.env` | Cumple | No leí `.env`. Sin variables nuevas en el diff; `NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1` no es secreto. |
| Imagen `api` sin root y `/health` | Cumple | `api` sano en el stack; `Containerfile` de `api` sin cambios. |
| Idioma de comentarios y textos | Pendiente de revisión humana | Aprueba el PR Federico Pizarro. |

## Fallos

Ninguno.

## Observaciones

1. Severidad baja. Un reinicio dentro de los 5 s de `valid` puede dar un 502 breve. En las pruebas el primer intento tras el reinicio no fue 200 y el segundo sí, por el arranque de `api`. La spec lo deja fuera.
2. Severidad baja. Referencias históricas a `nginx.conf` en la constitución y el plan (ver arriba).

## Criterios sin prueba

Ninguno. La web no se probó en un navegador; las pruebas fueron por `curl` contra el proxy.
