# Informe de seguridad — spec 004

Rama: `feat/004-endurecer-contenedores`. Fecha: 2026-10-15. Auditoría completa (CA-11), comparada con `docs/security/2026-10-15-auditoria-inicial.md`.

## Veredicto: APROBADO

No hay bloqueantes. DS-0002 ya no aparece. No hay hallazgos nuevos: los 48 CVE de la imagen `api` son los mismos de los hallazgos 2 y 3 de la auditoría inicial.

## Herramientas y comandos

- Semgrep 1.180.0 (imagen `docker.io/semgrep/semgrep`, Podman; no está en el PATH):
  `podman run --rm -v "$PWD:/src:Z" -w /src docker.io/semgrep/semgrep semgrep scan --config p/python --config p/security-audit --config p/secrets --config p/dockerfile --exclude=.env --exclude=.venv --exclude=.pubcache --exclude=.superpowers --exclude=web/build --exclude=.dart_tool --metrics=off api web compose.yaml`
  Resultado: 246 reglas, 54 archivos, 0 hallazgos.
- Trivy 0.76.0, sistema de archivos:
  `trivy fs --scanners vuln,secret,misconfig --skip-files .env --skip-dirs '**/.venv,.pubcache,.superpowers,web/build,**/.dart_tool' --severity HIGH,CRITICAL --quiet .`
  Resultado: 0 vulnerabilidades, 0 secretos, 0 misconfiguraciones. Ambos Containerfiles quedan limpios.
- Imágenes: `podman compose build` con `POSTGRES_PASSWORD` y `JWT_SECRET` aleatorios en el entorno (sin leer `.env`), luego `podman save` y `trivy image --input <tar> --severity HIGH,CRITICAL --quiet`.
  - `brewtrack-web:0.1.0` (alpine 3.24.2): 0 hallazgos.
  - `brewtrack-api:0.1.0` (debian 13.7): 44 HIGH en Debian, 4 HIGH en paquetes Python, 0 CRITICAL.
- Comprobaciones manuales con la imagen construida y secretos de prueba por entorno:
  - Secreto de 31 caracteres: salida 1, mensaje nombra `JWT_SECRET` y "menos de 32 caracteres", el valor no aparece.
  - Secreto de la plantilla: salida 1, mensaje dice "valor de la plantilla", el valor no aparece.
  - `web`: usuario `nginx`, `id -u` da 101.

## Hallazgos

| Hallazgo | Herramienta | Severidad | Archivo:línea | Bloqueante | Arreglo propuesto |
|---|---|---|---|---|---|
| 44 CVE en paquetes Debian de `python:3.13-slim`, sin versión corregida (`affected`, `fix_deferred`) | Trivy image | HIGH | imagen `brewtrack-api:0.1.0` | No (anterior al cambio) | Reconstruir cuando Debian publique parches. |
| `msgpack` 1.1.2 (fix 1.2.1), `setuptools` 70.3.0 (fix 78.1.1), `urllib3` 2.7.0 (fix 2.8.0, 2 CVE) | Trivy image | HIGH | imagen `brewtrack-api:0.1.0` | No (anterior al cambio; no es CRITICAL) | Fijar versiones o añadir lockfile en `api/`. Fuera de alcance de la spec 004. |

Sin hallazgos CRITICAL. Sin hallazgos nuevos.

## Revisión manual

- `api/app/config.py`: el validador de `jwt_secret` (líneas 21-29) rechaza menos de 32 caracteres y el valor de la plantilla, y sus mensajes no incluyen el valor. `_load` (líneas 41-48) usa `include_input=False`, `include_url=False` e `include_context=False`, y termina con `SystemExit`: sin traza ni `input_value`. Comprobado en ejecución: el valor no aparece en la salida. La plantilla de `config.py:8` coincide con `.env.example`, un valor de ejemplo, no un secreto.
- `web/brewtrack-web.Containerfile`: `USER nginx` en la línea 17, base `nginx:alpine` (CA-14), `EXPOSE 8080`. El `sed` quita `user` y mueve el pid a `/tmp`. El `chown` cubre solo `/var/cache/nginx` y `/etc/nginx/conf.d`, no la configuración principal. Sin secretos en el archivo.
- `compose.yaml` y `web/templates/default.conf.template`: `8080:8080` y `listen 8080`. Solo `web` publica puerto. `db` y `api` no.
- Nota menor, no es un hallazgo: la imagen declara los puertos 80 y 8080 expuestos (el 80 viene de la imagen base). Nginx solo escucha en 8080.

## Falsos positivos

Ninguno.

## Deuda previa al cambio

Hallazgos 2 y 3 (arriba) y los hallazgos 5 a 11 de la auditoría inicial, que la spec deja fuera de alcance. Esta revisión no los volvió a evaluar salvo los dos de imagen.

## Incidencias de herramienta

Ningún comando falló. Podman ya estaba activo.
