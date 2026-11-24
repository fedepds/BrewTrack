# Análisis de imágenes

Fuente: `slim xray` y `slim build` (SlimToolkit) en el build 16 de Jenkins, commit `31d6f23`, 24/11/2026. Los informes completos de cada corrida quedan en `reports/slimtoolkit/` como artefactos de Jenkins.

- **Tamaño:** suma de las capas sin comprimir, según SlimToolkit. Entre paréntesis, lo que ocupa comprimida en el registro.
- **Capas:** capas de sistema de archivos del manifiesto, incluidas las de la imagen base.

## Resumen

| Imagen | Base | Tamaño | Capas | De la base | Nuestras |
|---|---|---|---|---|---|
| `brewtrack-db:0.1.0` | `postgres:17-alpine` | 301,1 MB (119,4 MB) | 11 | 291,1 MB | 10,1 MB |
| `brewtrack-api:0.1.0` | `python:3.13-slim` | 280,1 MB (84,5 MB) | 8 | 143,6 MB | 136,6 MB |
| `brewtrack-web:0.2.0` | `nginx:1.30-alpine` | 114,7 MB (46,2 MB) | 11 | 62,0 MB | 52,8 MB |
| `brewtrack-web:0.2.0-slim` | reducida con `slim build` | 55,3 MB | 1 | — | — |

La `web` reducida pesa 59,4 MB menos (51,8 %). Pasa la sonda HTTP, la prueba de la ruta interna de la SPA y Trivy sin hallazgos HIGH ni CRITICAL. El clúster usa la normal.

Desde el cambio 1 de la spec 010, el pipeline solo corre `xray`. La reducida se mide a mano con `ci/slimtoolkit.sh reduce <imagen web>`, que no pasa Trivy: el resultado de Trivy de arriba es del build 16, y una medición local nueva no lo renueva.

## db

- La capa que compila PostgreSQL pesa 280,3 MB. Dentro, `libLLVM.so.21.1` (el JIT) ocupa 164 MB y los datos de ICU 33 MB.
- Nuestra única capa es `apk upgrade` (10,1 MB), que reescribe `libcrypto`, `libssl` y otras librerías de la base.

**Observaciones:**
- Casi todo el tamaño viene de la imagen oficial. Para sacar LLVM habría que compilar PostgreSQL propio, y no lo recomendamos.
- `apk upgrade` se queda mientras Trivy lo necesite para corregir vulnerabilidades.

## api

- Las dependencias de Python (capa 5) suman 94,9 MB. Las más grandes son `uvloop` (16,3 MB), el `libcrypto` propio de `psycopg_binary` (5,5 MB) y `pydantic_core` (4,5 MB).
- `apt-get upgrade` (capa 4) pesa 41,6 MB y cambia 481 archivos de la base, que quedan guardados dos veces.
- 88 archivos repetidos (3 MB perdidos), 8 binarios con setuid (`su`, `mount`, `passwd`, entre otros) y `bash`.

**Observaciones:**
- Cambiar a una base más nueva y quitar `apt-get upgrade` ahorraría hasta unos 40 MB, siempre que Trivy siga sin hallazgos.
- Quitar los binarios con setuid no ahorra espacio, pero reduce la superficie de ataque.
- No aplicamos `slim build` a `api`: la sonda HTTP no recorre todos los caminos del código, y la imagen podría fallar más tarde, en producción.

## web

- La app Flutter (capa 9) pesa 44,7 MB. De eso, `canvaskit/` ocupa 38,5 MB, con seis versiones del motor de dibujo (la mayor, `canvaskit.wasm`, 7,2 MB). `main.dart.js` pesa 3,1 MB.
- La capa base de nginx (48,8 MB) trae módulos que no usamos, como `acme-debug` (7 MB), `njs` y `libaom` (6,6 MB).
- `apk upgrade` agrega 8 MB.

**Observaciones:**
- `slim build` quita los módulos sobrantes de nginx, los paquetes y `apk upgrade`: el sistema baja de 70 MB a 10,6 MB. La app queda entera, así que hoy es el 81 % de la reducida.
- El margen que queda está en `canvaskit/`. Servir solo la versión que usa el navegador ahorraría hasta unos 30 MB. Antes hay que confirmar cuál carga.

## Anexos: salida de SlimToolkit

Copiamos la salida del build 16 en [`image-analysis/`](image-analysis/). Los JSON completos de `xray` (8,7 MB en total) quedan solo en Jenkins.

| Archivo | Qué es |
|---|---|
| [`brewtrack-db-0.1.0-31d6f23.xray.log`](image-analysis/brewtrack-db-0.1.0-31d6f23.xray.log) | Log de `slim xray` de `db` |
| [`brewtrack-api-0.1.0-31d6f23.xray.log`](image-analysis/brewtrack-api-0.1.0-31d6f23.xray.log) | Log de `slim xray` de `api` |
| [`brewtrack-web-0.2.0-31d6f23.xray.log`](image-analysis/brewtrack-web-0.2.0-31d6f23.xray.log) | Log de `slim xray` de `web` |
| [`brewtrack-web-0.2.0-31d6f23.build.log`](image-analysis/brewtrack-web-0.2.0-31d6f23.build.log) | Log de `slim build` de `web`: sonda HTTP y resultado |
| `brewtrack-{db,api,web}-*.txt` | Resumen por capa de cada imagen, generado desde el JSON de `xray` |
| [`brewtrack-web-0.2.0-31d6f23.compare.txt`](image-analysis/brewtrack-web-0.2.0-31d6f23.compare.txt) | Comparación de la `web` normal y la reducida |

Líneas clave de los logs:

```
db   xray   info=layers.count value='11'
api  xray   info=layers.count value='8'
web  xray   info=layers.count value='11'
web  build  info=http.probe.summary total='4' failures='0' successful='4'
web  build  info=results status='MINIFIED' by='2.07X' size.original='115 MB' size.optimized='55 MB'
```

Cómo leer los logs:

- El log de `slim build` trae 181 líneas `level=error` con `dst already exists (no op)`. Aparecen cuando el sensor intenta copiar dos veces el mismo archivo, y no afectan el resultado.
- El script fija `slim 1.40.11`, pero el sensor dice ser `x.1.42.2`. Falta confirmar cuál corre en realidad.
- Las palabras `password` que aparecen en los logs son el campo `no_password_login` de los usuarios de cada imagen, no secretos.
