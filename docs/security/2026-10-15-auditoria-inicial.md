# Auditoría de seguridad inicial — 2026-10-15

**Alcance:** todo el código de la rama `master` (`api/`, `web/`, `compose.yaml`, Containerfiles). No hay spec ni cambio concreto.

## Veredicto: RECHAZADO

Queda un bloqueante: `web/brewtrack-web.Containerfile` no declara `USER` (Trivy DS-0002, HIGH). No hay secretos versionados. Semgrep no encontró nada. La imagen de la API no tiene CRITICAL.

## Herramientas y comandos

- Semgrep 1.180.0 (imagen `docker.io/semgrep/semgrep`, Podman; no está en el PATH):
  `podman run --rm -v "$PWD:/src:Z" -w /src docker.io/semgrep/semgrep semgrep scan --config p/python --config p/security-audit --config p/secrets --config p/dockerfile --exclude=.env --exclude=.venv --exclude=.pubcache --exclude=.superpowers --exclude=web/build --exclude=.dart_tool --metrics=off api web compose.yaml`
  Resultado: 246 reglas, 54 archivos, 0 hallazgos.
- Trivy 0.76.0, sistema de archivos:
  `trivy fs --scanners vuln,secret,misconfig --skip-files .env --skip-dirs '**/.venv,.pubcache,.superpowers,web/build,**/.dart_tool' --severity HIGH,CRITICAL --quiet .`
  Resultado: `web/pubspec.lock` limpio, 0 secretos, 1 misconfiguración (DS-0002).
- Imágenes: `podman compose build` (con variables ficticias, sin leer `.env`), luego `podman save` y `trivy image --input <tar> --severity HIGH,CRITICAL`.
- Revisión manual con `code-security` de todos los archivos de `api/app`, `compose.yaml`, ambos Containerfiles, `web/templates/default.conf.template` y el almacenamiento de tokens en `web/lib/api.dart`.

Incidencias de herramienta:
- La máquina de Podman estaba parada y se cayó durante el primer `pull` de Semgrep. Se reinició y funcionó.
- `trivy image --image-src podman` falla en macOS (`no podman socket found`). Se usó `podman save` con `--input`. El tar temporal se borró.
- Con zsh, las variables `$RULES` y `$EXCL` del comando base no se expanden en palabras sueltas. Se pasaron los flags directos.

## Hallazgos

| # | Hallazgo | Herramienta | Severidad | Archivo:línea | Bloqueante | Arreglo propuesto |
|---|---|---|---|---|---|---|
| 1 | La imagen `web` no define `USER`: nginx arranca como root | Trivy DS-0002 | HIGH | `web/brewtrack-web.Containerfile:8` | Sí | Usar `nginxinc/nginx-unprivileged:alpine`, cambiar `listen 80` a `8080` en `web/templates/default.conf.template` y el puerto en `compose.yaml` a `"8080:8080"`. |
| 2 | 44 CVE HIGH en paquetes Debian de `python:3.13-slim` (util-linux, ncurses, systemd, acl, perl-base). Ninguno tiene versión corregida (`affected` o `fix_deferred`) | Trivy image | HIGH | imagen `brewtrack-api:0.1.0` | No | Reconstruir cuando Debian publique parches. Impacto bajo: el proceso corre como `app` y esos binarios no se exponen. |
| 3 | `msgpack` 1.1.2 (fix 1.2.1), `setuptools` 70.3.0 (fix 78.1.1), `urllib3` 2.7.0 (fix 2.8.0, 2 CVE): HIGH con versión corregida | Trivy image | HIGH | imagen `brewtrack-api:0.1.0` (paquetes Python) | No (no son CRITICAL) | Reconstruir sin caché y fijar versiones. `pyproject.toml` usa solo `>=` y no hay lockfile. Origen de `msgpack` y `urllib3` sin determinar: no son dependencias directas. |
| 4 | `JWT_SECRET` sin longitud mínima: acepta `change-me` de `.env.example` | revisión manual | MEDIUM | `api/app/config.py:9` | No | Validar `len >= 32` en `Settings` y rechazar el valor de la plantilla. |
| 5 | `POST /auth/login` sin límite de intentos | revisión manual | MEDIUM | `api/app/routers/auth.py:39` | No | Límite por IP y email en nginx (`limit_req`) o en la API. |
| 6 | Refresh token sin revocación y guardado en `localStorage` (`shared_preferences`) | revisión manual | MEDIUM | `web/lib/api.dart:63` | No | Decisión de diseño (spec, sección Frontend). Si cambia, usar cookie `HttpOnly`. Sin XSS conocido hoy. |
| 7 | Sin cabeceras de seguridad en nginx (CSP, `X-Content-Type-Options`, `X-Frame-Options`) | revisión manual | LOW | `web/templates/default.conf.template` | No | Añadir `add_header` en `server`. |
| 8 | `/api/v1/docs` y `openapi.json` públicos sin login | revisión manual | LOW | `api/app/main.py:24` | No | Aceptable en un taller. Apagar `docs_url` si se expone a Internet. |
| 9 | Filtros `country` y `process` pasan `%` y `_` del usuario a `ilike` (comodines, no inyección SQL: van parametrizados) | revisión manual | LOW | `api/app/routers/green_lots.py:68,70` | No | Escapar con `.ilike(..., escape="\\")`. |
| 10 | Imágenes sin versión fija (`flutter:stable`, `nginx:alpine`, `python:3.13-slim`) | revisión manual | LOW | `web/brewtrack-web.Containerfile:1,8`, `api/brewtrack-api.Containerfile:1,7` | No | Fijar etiqueta o digest. |
| 11 | `notes` sin longitud máxima en lotes y tuestes | revisión manual | LOW | `api/app/routers/green_lots.py:27`, `api/app/routers/roasts.py:34` | No | Añadir `max_length`. |

### Evaluación de DS-0002 (hallazgo 1)

Confirmado. La etapa final (`nginx:alpine`, línea 8) no tiene `USER`. En la imagen oficial el proceso maestro corre como root y los workers como `nginx`. Un fallo en nginx da menos poder que un proceso root completo, pero el maestro conserva root y el puerto 80 lo exige. La spec pide modo rootless en Podman, lo que reduce el riesgo en el host. Se clasifica bloqueante por la regla de la auditoría (HIGH real en el código). La imagen de la API sí cumple: `USER app` en `brewtrack-api.Containerfile:13`.

## Revisión manual: lo que está bien

- Permisos: `users` exige `admin_only` en todo el router. `green-lots`, `roasts` y `stats` exigen `current_user`. Los `DELETE` exigen `admin_only`. `PATCH /roasts` comprueba autor o admin.
- JWT: HS256 fijo en `decode`, `exp`, `iat` y `typ` comprobados, secreto de `settings`. Un usuario inactivo pierde el acceso en cada petición.
- Contraseñas con argon2. El login responde igual si el email no existe o la contraseña falla.
- SQL: solo SQLAlchemy con parámetros. Sin SQL en texto ni `f-string` en consultas.
- Errores con formato `{"error": {...}}`, sin trazas. 500 sin manejador propio devuelve el cuerpo genérico de Starlette.
- CORS cerrado a `cors_origins`. Solo `web` publica puerto. `db` no se expone.
- Secretos: `.env` está en `.gitignore` y no está versionado. `.env.example` solo tiene valores de ejemplo.

## Falsos positivos

Ninguno.

## Deuda previa

Todos los hallazgos son anteriores a esta auditoría (no hay cambio de referencia). Los no bloqueantes son 2 a 11.
