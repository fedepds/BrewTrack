# Informe de seguridad — spec 005

Rama: `feat/005-rebranding-tostado` (cambios sin commit). Fecha: 2026-10-15. Cambio solo de `web/`; `api/` no cambió.

## Veredicto: APROBADO

No hay bloqueantes. Queda un hallazgo menor sobre las fuentes de respaldo de Flutter (abajo) que QA debe vigilar en CA-16.

## Herramientas y comandos

- Semgrep (imagen `docker.io/semgrep/semgrep`, Podman; no está en el PATH), mismo comando que en la spec 004 (`p/python`, `p/security-audit`, `p/secrets`, `p/dockerfile` sobre `api web compose.yaml`, con las exclusiones habituales). Resultado: 246 reglas, 58 archivos, 0 hallazgos.
- Trivy 0.76.0, sistema de archivos (`--scanners vuln,secret,misconfig`, HIGH y CRITICAL): 0 vulnerabilidades (`web/pubspec.lock`), 0 secretos, 0 misconfiguraciones en ambos Containerfiles.
- Imágenes (`podman save` + `trivy image --input`) sobre las etiquetas `0.1.0` ya construidas por el stack local (creada 23:20 UTC, con las fuentes dentro):
  - `brewtrack-web` (alpine 3.24.2): 0 hallazgos.
  - `brewtrack-api` (debian 13.7): 44 HIGH Debian, 4 HIGH Python, 0 CRITICAL. Iguales a la spec 004.
- Comprobaciones manuales en el contenedor `web` en marcha.

## Hallazgos

| Hallazgo | Herramienta | Severidad | Archivo:línea | Bloqueante | Arreglo propuesto |
|---|---|---|---|---|---|
| `main.dart.js` conserva la URL `https://fonts.gstatic.com/s/` (fuente de respaldo de Flutter para glifos que faltan en las tres fuentes). Solo se pide si un texto usa un carácter que ninguna fuente cubre (p. ej. un emoji). | Revisión manual | Baja | imagen `brewtrack-web`, `main.dart.js` | No | Vigilar en CA-16. Si hace falta cerrarlo del todo, añadir a nginx `Content-Security-Policy` con `connect-src 'self'` y `font-src 'self'`, o fijar `fontFamilyFallback` a una fuente local. |
| 44 CVE Debian y 4 en paquetes Python de la imagen `api` | Trivy image | HIGH | imagen `brewtrack-api:0.1.0` | No (anterior al cambio) | Ver spec 004. |

Sin hallazgos CRITICAL ni nuevos en código.

## Revisión manual por punto pedido

1. **Semgrep y Trivy:** limpios (arriba).
2. **Sin peticiones externas (RF-14 / CA-16):**
   - `web/web/index.html` no carga scripts, hojas de estilo ni fuentes externas. Solo `flutter_bootstrap.js` local (línea 44). Las URLs de las líneas 12 y 42 están en comentarios.
   - `web/brewtrack-web.Containerfile:6`: `flutter build web --release --no-web-resources-cdn`.
   - En la imagen servida: `flutter_bootstrap.js` lleva `"useLocalCanvasKit":true` y `canvaskit/` (`canvaskit.js`, `.wasm`) está en el directorio de nginx. Las menciones `gstatic.com/flutter-canvaskit` en `flutter.js` y `flutter_bootstrap.js` son el valor por defecto, que no se usa con `useLocalCanvasKit`. Falta confirmar con las herramientas de red del navegador (QA, CA-16).
   - Excepción: el hallazgo de `fonts.gstatic.com` (arriba).
   - Nota: el `web/build/web` local (solo lectura) también contiene esas cadenas por defecto; no se usó como prueba, sí la imagen.
3. **Fuentes:** cuatro TTF reconocidos por `file` como TrueType válido (Big Shoulders Stencil y Public Sans variables; IBM Plex Mono Regular y Medium). Cada familia trae su `OFL-*.txt` con "SIL Open Font License, Version 1.1" y su copyright. `FontManifest.json` de la imagen las registra y los TTF están en `assets/assets/fonts/`. Los `OFL` de IBM Plex Mono tienen terminaciones CRLF: sin efecto.
4. **`index.html` y `manifest.json`:** el diff solo cambia título, descripción, nombre y colores (`#6F4E37`). Sin scripts nuevos ni URLs. `logo.png` (720x496) y `bean.png` (192x192) son PNG válidos.
5. **Spec 004 intacta:** `web/brewtrack-web.Containerfile` solo cambia el flag de build. Plantilla de nginx y `compose.yaml` sin modificar. El contenedor corre con usuario `nginx` (uid 101), `listen 8080`, procesos master y worker como `nginx`. `GET /` responde 200. nginx no añade cabeceras de seguridad (ni antes ni ahora; no es regresión).
6. Sin dependencias nuevas en `pubspec.yaml` (solo `assets` y `fonts`). `assets: - assets/` empaqueta también los `OFL-*.txt`: es lo deseable para la licencia.

## Falsos positivos

Ninguno.

## Deuda previa al cambio

Hallazgos 2, 3 y 5 a 11 de la auditoría inicial (ver spec 004), incluida la ausencia de cabeceras de seguridad en nginx. Sin cambios.

## Incidencias de herramienta

Ningún comando falló. Semgrep corrió por Podman. `ls --time-style` no existe en macOS (sin impacto).
