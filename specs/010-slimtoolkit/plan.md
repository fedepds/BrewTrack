# 010 — Plan

## Constitución

| Regla | Cómo la cumple este cambio |
|---|---|
| Alcance | Solo CI: un script, dos etapas y un análisis. No toca la app. |
| Stock, permisos, errores | No aplican: sin cambios en API, datos ni app. |
| Esquema | Sin migraciones. |
| Secretos | Ninguno. El script no lee `.env`. |

## Diseño

- `ci/slimtoolkit.sh xray|reduce DB_REF API_REF WEB_REF`. Escribe en `reports/slimtoolkit/`.
- `ci/slimtoolkit-summary.py`: resumen de texto (total y una línea por capa) a partir del JSON de `xray`.
- slim 1.40.11: binario oficial de las releases (arm64 o amd64), con sha256 fijo, corrido dentro de un `docker:29.10.0-dind` desechable (almacén clásico, `--privileged`, sin puertos; ver `docs/security/2026-11-23-slimtoolkit-dind.md`). Motivos: slim no exporta imágenes del almacén containerd del host, y la imagen `dslim/slim` es solo amd64 (su sensor falla emulado). Sin bind mounts de `$PWD`, porque Jenkins corre en un contenedor: los datos salen por `docker exec`, stdin y stdout.
- `xray`: carga cada imagen y su base en el dockerd interno, corre `xray --changes all` y deja `<imagen>-<etiqueta>.xray.json`, `.xray.log` y `.txt`. Una imagen que falla no corta a las otras; el script sale con 1 al final.
- `reduce WEB_REF`: `slim build` de `web` (sonda HTTP en 8080; conserva `/usr/share/nginx/html`, `/etc/nginx`, `/docker-entrypoint.sh`, `/docker-entrypoint.d` y el shell), levanta la imagen reducida, comprueba con `curl` 200 en las rutas de `WEB_CHECK_PATHS` (parámetro del build; por defecto `/`, `/index.html`, `/lotes/ejemplo`, `/main.dart.js`), que una ruta interna devuelva el mismo cuerpo que `/index.html`, y usuario `nginx`. Escribe `<imagen>-<etiqueta>.compare.txt`. Solo si todo pasa, copia `<WEB_REF>-slim` al Docker del host.
- `Jenkinsfile`: etapa `SlimToolkit análisis` en paralelo con Trivy y Snyk; etapas `Reducir web (SlimToolkit)` y `Trivy web reducida` tras `Build imágenes`. Todas con `catchError` a UNSTABLE. `Publicar imágenes` sube la `-slim` solo si `SLIM_OK`. `Deploy Helm` no cambia. `post always` borra los contenedores de la prueba.
- `.gitignore`: `reports/slimtoolkit/`.
