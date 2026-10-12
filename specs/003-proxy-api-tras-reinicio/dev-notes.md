# 003 — Notas de desarrollo

## Qué cambió
- `web/nginx.conf` -> `web/templates/default.conf.template`: `resolver ${NGINX_LOCAL_RESOLVERS} valid=5s;` y `proxy_pass` con variable.
- `web/Containerfile`: copia la plantilla a `/etc/nginx/templates` y define `NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1`.

## Mecanismo
nginx resuelve el nombre una vez si `proxy_pass` lleva un nombre fijo. Con una variable lo resuelve en cada petición, con el `resolver` y el TTL (`valid=5s`). La imagen oficial rellena `NGINX_LOCAL_RESOLVERS` con el `nameserver` de `/etc/resolv.conf` del contenedor, así que la IP del DNS no queda escrita en el repo.

## Cómo comprobé el DNS
`podman exec <web> cat /etc/resolv.conf`:
- Stack `brewtrack2` (red 10.89.10.x): `nameserver 10.89.10.1`.
- Stack de prueba `bt003` (red 10.89.11.x): `nameserver 10.89.11.1`.

No es `127.0.0.11` y cambia por red. En `bt003`, `grep resolver /etc/nginx/conf.d/default.conf` mostró `resolver 10.89.11.1 valid=5s;`, o sea que la plantilla tomó el valor correcto. Una IP fija habría fallado en una de las dos redes.

## Cómo probarlo
`podman compose up --build -d`, luego `podman compose restart api` y `curl http://localhost:8080/api/v1/health` sin tocar `web`.

## Resultados
Stack temporal `bt003`, web en el puerto 8093 en lugar de 8080 (el 8080 es del stack del usuario, que no se tocó), volumen nuevo, env temporal con valores de prueba.
- CA-1 y CA-2: tras cada uno de 3 reinicios de `api`, `/api/v1/health` dio 200 al segundo intento (unos 2 s), sin reiniciar `web`.
- CA-3: con sesión, `GET /api/v1/green-lots?limit=5&offset=0` devolvió `limit` 5, `offset` 0 y 5 elementos.
- CA-4: sin token, 401 con `{"error":{"code":"unauthorized","message":"Credenciales inválidas o ausentes"}}`.
- CA-5: `/lotes` responde 200 con `index.html`.
- CA-6: `pytest` 96 pasan; `flutter analyze` sin problemas; `flutter test` 15 pasan.

Se borraron el proyecto, el volumen, las imágenes `bt003-*` y el env y compose temporales.

## Pendiente
- Un reinicio dentro de los 5 s de `valid` puede dar un 502 breve mientras `api` arranca. La spec lo deja fuera.
- `podman compose up --build` mostró "identifier is not a container" al borrar el contenedor de build y salió con error, aunque la imagen se construyó. Es del entorno; `up -d` después levantó el stack.
