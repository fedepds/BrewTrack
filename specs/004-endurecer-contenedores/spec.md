# 004 — Endurecer el contenedor web y el secreto JWT

Estado: aprobada
Fecha: 2026-10-15

## Contexto y objetivo

La auditoría de seguridad `docs/security/2026-10-15-auditoria-inicial.md` rechazó el estado actual de `master`. Esta spec cubre dos de sus hallazgos:

- **Hallazgo 1 (HIGH, bloqueante, Trivy DS-0002).** La imagen `web` no declara `USER`. El proceso maestro de nginx corre como root, y lo necesita porque escucha en el puerto 80 dentro del contenedor.
- **Hallazgo 4 (MEDIUM).** La API acepta cualquier `JWT_SECRET`, incluso uno de pocos caracteres. Con un secreto corto, alguien puede adivinarlo y firmar tokens válidos para cualquier usuario.

Objetivo: que el informe de seguridad quede sin bloqueantes y que la API no arranque con un secreto débil. El taller no debe notar ningún otro cambio: la misma URL, el mismo login y los mismos datos.

## Historias de usuario

- HU-1. Como `admin`, quiero que el contenedor `web` corra sin root, para que un fallo en nginx no dé control de root dentro del contenedor.
- HU-2. Como `admin`, quiero que la API se niegue a arrancar con un `JWT_SECRET` corto o copiado de la plantilla, y que me diga por qué, para no dejar el taller con tokens fáciles de falsificar.
- HU-3. Como `admin`, quiero seguir entrando por http://localhost:8080 después del cambio, sin aprender nada nuevo.

## Requisitos funcionales

### Contenedor web sin root

- RF-1. Ningún proceso de nginx en el contenedor `web` corre como root (UID 0), ni el maestro ni los workers.
- RF-2. El taller sigue entrando por http://localhost:8080. Si cambia el puerto dentro del contenedor, `compose.yaml` lo mapea para que el puerto del host siga siendo 8080.
- RF-3. Solo `web` publica un puerto al host, como hoy.
- RF-4. El proxy de `/api/` sigue igual: la misma ruta, la misma query y las mismas cabeceras llegan a la API. El arreglo de la spec 003 sigue funcionando: tras reiniciar `api`, la web vuelve a llegar a la API sin reiniciar `web`.
- RF-5. La SPA sigue igual: cualquier ruta fuera de `/api/` sirve `index.html`.
- RF-6. La imagen de runtime de `web` sigue siendo `nginx:alpine`, como fija la constitución, y nginx corre en ella con un usuario sin root (ver D-1). El developer elige el usuario y el puerto dentro del contenedor, y anota en `dev-notes.md` cómo comprobó RF-1.

### Secreto JWT con longitud mínima

- RF-7. La API no arranca si `JWT_SECRET` tiene menos de 32 caracteres.
- RF-8. La API no arranca si `JWT_SECRET` es igual al valor de ejemplo de `.env.example`, aunque tenga 32 caracteres o más.
- RF-9. En los dos casos, la API termina con un código de salida distinto de 0 y un mensaje en español que nombra `JWT_SECRET` y el motivo (menos de 32 caracteres, o valor de la plantilla).
- RF-10. Ni el mensaje ni ninguna otra salida (logs, trazas, errores de validación) muestra el valor de `JWT_SECRET`, ni entero ni en parte.
- RF-11. Con un `JWT_SECRET` de 32 caracteres o más que no sea el de la plantilla, la API arranca y funciona como hoy.
- RF-12. `.env.example` dice el mínimo de 32 caracteres y cómo generar un secreto válido. El README dice lo mismo donde explica cómo rellenar `.env`. Además, el README avisa a las instalaciones existentes de que la API no arranca con un secreto corto o con el de la plantilla, da el comando para generar uno nuevo y advierte que, al cambiarlo, todos los usuarios tendrán que volver a entrar (ver D-2).
- RF-13. Los tests de la API usan un secreto válido (32 caracteres o más, distinto del de la plantilla) y siguen pasando. Hay tests nuevos que prueban RF-7, RF-8, RF-10 y RF-11.

## Criterios de aceptación

CA-1 a CA-6 y CA-11 son pruebas manuales de QA sobre el stack levantado con `podman compose up --build -d` y un `.env` válido. CA-7 a CA-10 son pruebas automáticas de pytest y pruebas manuales con la API en desarrollo.

- CA-1. Dado el stack sano, cuando QA ejecuta `podman compose exec web ps -o user,pid,args` (o un comando equivalente que muestre el usuario de cada proceso), entonces ningún proceso `nginx` aparece con usuario `root` o UID 0.
- CA-2. Dado el stack sano, cuando QA ejecuta `podman compose exec web id -u`, entonces el resultado es distinto de 0.
- CA-3. Dado el stack sano, cuando QA pide `GET http://localhost:8080/api/v1/health`, entonces recibe 200. Cuando pide `http://localhost:8080/lotes`, entonces recibe 200 con `index.html`.
- CA-4. Dado el stack sano y un usuario con sesión, cuando QA pide `GET http://localhost:8080/api/v1/green-lots?limit=5&offset=0`, entonces recibe 200 con `limit` 5 y `offset` 0 en el cuerpo. Sin token, la misma petición devuelve 401 con el cuerpo `{"error": {"code", "message"}}`.
- CA-5. Dado el stack sano, cuando QA ejecuta `podman compose restart api` y `api` vuelve a estar sano, entonces `GET http://localhost:8080/api/v1/health` responde 200 sin reiniciar `web`.
- CA-6. Dado el stack sano, cuando QA ejecuta `podman compose ps`, entonces `web` publica solo el puerto 8080 del host y ni `api` ni `db` publican puertos.
- CA-7. Dado un `JWT_SECRET` de 31 caracteres, cuando arranca la API (`uvicorn app.main:app` o `python -c "import app.main"`), entonces el proceso termina con código distinto de 0 y la salida contiene `JWT_SECRET` y `32`.
- CA-8. Dado `JWT_SECRET` igual al valor de `.env.example`, cuando arranca la API, entonces el proceso termina con código distinto de 0 y la salida contiene `JWT_SECRET` y dice que es el valor de la plantilla.
- CA-9. Dado CA-7 y CA-8, cuando QA busca el valor usado en toda la salida (stdout y stderr), entonces no lo encuentra, ni entero ni en fragmentos de 8 caracteres o más.
- CA-10. Dado un `JWT_SECRET` de 32 caracteres distinto de la plantilla, cuando arranca la API, entonces `GET /api/v1/health` responde 200 y `POST /api/v1/auth/login` con credenciales válidas devuelve tokens.
- CA-11. Dado el código de la entrega, cuando el agente `security` vuelve a correr la auditoría completa (Semgrep, Trivy de sistema de archivos y Trivy de las dos imágenes), entonces su informe tiene veredicto APROBADO, sin bloqueantes, y Trivy ya no reporta DS-0002 para `web/brewtrack-web.Containerfile`.
- CA-12. Dado el código de la entrega, cuando se ejecutan `cd api && pytest` y `cd web && flutter test`, entonces pasan, incluidos los tests nuevos de RF-13.
- CA-13. Dado el código de la entrega, cuando QA lee `.env.example` y el README, entonces los dos dicen el mínimo de 32 caracteres y dan un comando para generar un secreto válido. El README también avisa que una instalación con un secreto corto o de plantilla deja de arrancar y que, al cambiar el secreto, todos los usuarios tendrán que volver a entrar.
- CA-14. Dado el código de la entrega, cuando QA lee `web/brewtrack-web.Containerfile`, entonces la etapa final parte de `nginx:alpine`.

## Chequeo de constitución

- **Alcance:** aplica. Solo endurece el contenedor `web` y la configuración de la API del mismo taller. No añade funciones ni toca curvas, empaque, venta, recetas, cata ni multi-empresa.
- **Stock calculado:** no aplica. No cambia ningún cálculo ni dato.
- **Permisos en la API:** aplica. La API sigue imponiendo los permisos y el proxy solo reenvía (CA-4). Un secreto fuerte protege la firma de los tokens en que se basan esos permisos.
- **Formato de error:** aplica. Los errores de la API siguen con `{"error": {"code", "message"}}` (CA-4). El fallo de arranque por secreto débil no es una respuesta HTTP: la API no llega a escuchar, así que el formato no aplica a ese mensaje.
- **Migraciones:** no aplica. No cambia el esquema.
- **Secretos:** aplica. `JWT_SECRET` sigue entrando por variable de entorno. Nadie lee ni imprime `.env`. La API no imprime el secreto ni cuando lo rechaza (RF-10, CA-9). QA prueba con secretos de prueba pasados por el entorno, no con el de `.env`.

## Fuera de alcance / pendiente

Hallazgos de la auditoría que quedan para specs futuras:

- Hallazgo 2: 44 CVE HIGH en paquetes Debian de `python:3.13-slim`, sin versión corregida. Reconstruir cuando Debian publique parches.
- Hallazgo 3: `msgpack`, `setuptools` y `urllib3` con CVE HIGH y versión corregida. Fijar versiones o añadir lockfile en la API.
- Hallazgo 5: `POST /auth/login` sin límite de intentos.
- Hallazgo 6: refresh token sin revocación y guardado en `localStorage`. Cambiarlo es una decisión de diseño: la constitución fija hoy el refresh token en `localStorage`.
- Hallazgo 7: cabeceras de seguridad en nginx (CSP, `X-Content-Type-Options`, `X-Frame-Options`).
- Hallazgo 8: `/api/v1/docs` y `openapi.json` públicos sin login.
- Hallazgo 9: comodines `%` y `_` en los filtros `country` y `process`.
- Hallazgo 10: imágenes sin versión fija (`flutter:stable`, `nginx:alpine`, `python:3.13-slim`).
- Hallazgo 11: `notes` sin longitud máxima en lotes y tuestes.

También queda fuera:
- Rotar de forma automática el `JWT_SECRET` de instalaciones existentes. Si un taller ya usa un secreto corto, la API dejará de arrancar hasta que el `admin` ponga uno válido (ver D-2).
- Cambiar la imagen de runtime de `web` a otra que no sea `nginx:alpine` (ver D-1).
- Pruebas automáticas del stack de contenedores (la constitución deja fuera CI/CD).

## Decisiones

- D-1. **Imagen base de `web`.** Se mantiene `nginx:alpine` y nginx corre con un usuario sin root. No se usa `nginxinc/nginx-unprivileged:alpine`, que propone la auditoría, y no se cambia la constitución. Lo decidió el usuario el 2026-10-15.
- D-2. **Talleres con un secreto corto o de plantilla.** Se acepta que esas instalaciones dejen de arrancar. El README lo avisa, da el comando para generar un secreto nuevo y advierte que todos los usuarios tendrán que volver a entrar. Lo decidió el usuario el 2026-10-15.

## Preguntas abiertas

Ninguna.

## Historial

| Fecha | Versión | Cambio |
|---|---|---|
| 2026-10-15 | 1.0 | Versión inicial a partir de los hallazgos 1 y 4 de la auditoría de seguridad inicial. |
| 2026-10-15 | 1.1 | El usuario responde las dos preguntas abiertas, que pasan a "Decisiones" (D-1 y D-2). RF-6 fija `nginx:alpine` con un usuario sin root. RF-12 y CA-13 añaden el aviso del README para instalaciones existentes. Nuevo CA-14. Lista para aprobación. |
| 2026-10-15 | 1.1 | El usuario aprueba la spec. |
