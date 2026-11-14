# Informe de seguridad — 007 Imágenes con versiones fijas

Fecha: 2026-11-14
Rama: `feat/007-imagenes-versiones-fijas`

## Veredicto: APROBADO

No hay bloqueantes. Quedan seis hallazgos no bloqueantes (N-1 a N-6) y deuda previa. El uso de `--privileged` en el Docker temporal es aceptable con las mitigaciones de la sección "Evaluación de `--privileged` y el puerto 2375".

## Herramientas y versiones

| Herramienta | Versión | Vía |
|---|---|---|
| Semgrep | `semgrep/semgrep:1.184.0` | Docker (Colima) |
| Trivy | `aquasec/trivy:0.76.2` | Docker (Colima), socket montado |
| Revisión manual | skills `semgrep` y `code-security` | `scripts/slim-analysis.sh`, `Jenkinsfile`, tres Containerfiles |

`.env` no se leyó, no se imprimió y todos los escaneos lo excluyen.

## Archivos del cambio

`AGENTS.md`, `Jenkinsfile`, `api/brewtrack-api.Containerfile`, `db/brewtrack-db.Containerfile`, `web/brewtrack-web.Containerfile`, `docs/superpowers/specs/2026-10-07-brewtrack-design.md`, `reports/image-analysis.md`, `reports/slimtoolkit-ejecucion.md`, `scripts/slim-analysis.sh`, `specs/007-imagenes-versiones-fijas/*`.

## Comandos ejecutados

```bash
# Semgrep (código; se añadieron Jenkinsfile y scripts)
docker run --rm -v "$PWD:/src" -w /src semgrep/semgrep:1.184.0 semgrep scan \
  --config p/python --config p/security-audit --config p/secrets --config p/dockerfile \
  --exclude=.env --exclude=.venv --exclude=.pubcache --exclude=.superpowers --exclude=web/build --exclude=.dart_tool \
  --metrics=off api web compose.yaml Jenkinsfile scripts

# Trivy imágenes (regla del pipeline, RF-11), con y sin --ignore-unfixed
trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed --quiet [--skip-files usr/local/bin/gosu en db] localhost/brewtrack-{db,api,web}:0.1.0
trivy image --severity HIGH,CRITICAL --quiet [--skip-files usr/local/bin/gosu en db] localhost/brewtrack-{db,api,web}:0.1.0
trivy image --severity HIGH,CRITICAL --ignore-unfixed --quiet localhost/brewtrack-db:0.1.0     # sin la excepción de gosu
trivy image --severity HIGH,CRITICAL --ignore-unfixed --quiet docker:27.5.1-dind                # imagen del Docker temporal

# Trivy fs
trivy fs --exit-code 1 --scanners vuln,secret,misconfig --skip-files .env \
  --skip-dirs '**/.venv,.pubcache,.superpowers,web/build,**/.dart_tool' --severity HIGH,CRITICAL --quiet .
```

## Resultados

| Escaneo | Resultado |
|---|---|
| Semgrep (246 reglas, 60 archivos) | 0 hallazgos |
| Trivy imagen `api`, `--ignore-unfixed` (RF-11) | 0 (sale 0) |
| Trivy imagen `web`, `--ignore-unfixed` (RF-11) | 0 (sale 0) |
| Trivy imagen `db`, `--ignore-unfixed` y `--skip-files gosu` (RF-11) | 0 (sale 0) |
| Trivy imagen `api`, sin `--ignore-unfixed` | 47 HIGH, 0 CRITICAL, todas sin parche (`affected` y una `fix_deferred`) |
| Trivy imagen `web`, sin `--ignore-unfixed` | 0 |
| Trivy imagen `db`, sin `--ignore-unfixed` y sin `gosu` | 0 |
| Trivy imagen `db`, `--ignore-unfixed`, incluyendo `gosu` | 26 en `usr/local/bin/gosu` (25 HIGH, 1 CRITICAL, `stdlib` de Go 1.24.6 con parche en el Go de `gosu`): riesgo aceptado, ver `docs/security/2026-11-10-imagen-db.md` |
| Trivy `docker:27.5.1-dind` (solo informativo) | 69 con parche (62 HIGH, 7 CRITICAL), casi todo Go en `docker`, `containerd`, `ctr` y `runc` |
| Trivy fs | 2 CRITICAL por secretos en `docs/security/scan_semgrep.txt:17` y `:58` (falso positivo y previo, ver abajo) |

Los 47 HIGH de `api` son de paquetes Debian sin parche: `util-linux` y sus bibliotecas (`bsdutils`, `libblkid1`, `libmount1`, `libsmartcols1`, `libuuid1`, `liblastlog2-2`, `login`, `mount`; 4 CVE cada uno), `libsqlite3-0` (3), `ncurses`, `libacl1`, `libsystemd0`, `libudev1` (1 cada uno) y `perl-base` (1, `fix_deferred`). Ninguno cambió con esta spec.

## Hallazgos

| ID | Hallazgo | Herramienta | Severidad | Archivo:línea | Bloqueante | Arreglo propuesto |
|---|---|---|---|---|---|---|
| N-1 | El Docker temporal corre con `--privileged`; con root en el contenedor se escapa a la VM de Colima | Revisión manual | Media | `scripts/slim-analysis.sh:14` | No | Mitigaciones de la sección siguiente. Aceptado por D-5 |
| N-2 | `dockerd` escucha en `tcp://0.0.0.0:2375` sin TLS. No se publica en el host, pero cualquier contenedor de la red `bridge` por defecto de Colima puede llegar a la IP del contenedor mientras dura el análisis | Revisión manual | Media | `scripts/slim-analysis.sh:14` | No | Crear una red `docker network create` por build, con `--network` en el `dind` y en Slim (ver abajo), o escuchar solo en el socket Unix y compartirlo con un volumen |
| N-3 | La etapa no tiene tope de tiempo. Si Slim se cuelga (emulado en amd64), el contenedor `--privileged` sigue vivo hasta que alguien aborte. Un `SIGKILL` de Jenkins no ejecuta el `trap` y deja el contenedor | Revisión manual | Baja | `Jenkinsfile:97-102`, `scripts/slim-analysis.sh:11` | No | `options { timeout(time: 15, unit: 'MINUTES') }` en la etapa. Añadir al inicio del script `docker rm -f "$D" 2>/dev/null` para borrar restos de un build anterior |
| N-4 | El `trap` captura `INT` y `TERM` sin salir. En `sh` POSIX el script sigue tras el manejador y solo falla después, porque el contenedor ya no existe | Revisión manual | Baja | `scripts/slim-analysis.sh:11` | No | `trap cleanup EXIT; trap 'exit 130' INT; trap 'exit 143' TERM` |
| N-5 | `docker save "$img" \| docker exec -i ... docker load` sin `pipefail`: un fallo de `docker save` queda tapado por el código del `load`. Slim fallaría después, así que el efecto es un mensaje de error confuso | Revisión manual | Baja | `scripts/slim-analysis.sh:23` | No | Guardar a un archivo en `$TMP` y cargarlo después, o `set -o pipefail` si `sh` es `bash` |
| N-6 | La imagen `dslim/slim:1.40.11` no tiene mantenimiento desde 2024, es solo amd64 (corre emulada) y se lanza con acceso al `dockerd` temporal. No tiene versión nueva con parches | Revisión manual | Baja | `scripts/slim-analysis.sh:8,24` | No | Ver "Terceros con versión fija". Mantener el Docker temporal aislado y sin secretos |
| N-7 | `allowEmptyArchive: true` permite que el artefacto falte sin avisar. Es inocuo porque el script falla antes si faltan datos (RF-16) | Revisión manual | Informativa | `Jenkinsfile:101` | No | Quitar `allowEmptyArchive` para que la ausencia del archivo se vea |

## Evaluación de `--privileged` y el puerto 2375 (D-5)

**Alcance de la exposición.** El `docker run -d` (`scripts/slim-analysis.sh:14`) no lleva `-p` ni `-P`: el puerto 2375 no se publica en el host ni en la VM. El `dockerd` interno escucha en `0.0.0.0:2375` dentro del espacio de red del contenedor `slim-dind-<BUILD_NUMBER>`. Slim lo alcanza con `--network container:$D` y `DOCKER_HOST=tcp://127.0.0.1:2375` (línea 24), así que no necesita red propia. Aun así, el contenedor queda en la red `bridge` por defecto, con IP interna: otros contenedores de esa red (incluido cualquier otro contenedor de otro build, otro agente o minikube si comparte la red) podrían conectarse a `tcp://<ip>:2375` sin autenticación y, con `--privileged`, ejecutar código como root en la VM. No lo comprobé en vivo para no dejar un contenedor privilegiado corriendo; sale de leer el script y de la documentación de la imagen `docker:dind`.

**Duración.** Desde el arranque hasta el `trap EXIT`: unos minutos en el caso normal (espera de hasta 120 s al arranque y luego un `slim xray` por imagen, emulado). Sin tope de tiempo (N-3).

**Limpieza.** `trap cleanup EXIT INT TERM` (línea 11) borra el contenedor con `docker rm -f` y el directorio temporal. Cubre éxito y fallo del script, como pidió CA-12. No cubre `SIGKILL`, ni la muerte del agente. El nombre `slim-dind-${BUILD_NUMBER:-$$}` es distinto en cada build y `disableConcurrentBuilds()` evita choques, pero un resto de un build abortado no se borra (N-3).

**Inyección.** Sin hallazgo. `OUT` y `img` vienen del `Jenkinsfile`, con literales fijos. `BUILD_NUMBER` es numérico. Todas las variables van entre comillas (`"$D"`, `"$img"`, `"$SLIM"`, `"$OUT"`, `"$TMP/log"`). `$@` no se reparte sin comillas: el `for img in "$@"` conserva cada argumento. Un nombre de imagen que empiece por `-` se leería como opción de `docker save`, pero hoy no hay entrada externa. `set -eu` activo (línea 5) y la salida de Slim va a un archivo, no se evalúa.

**Secretos.** El script no lee `.env` y no pasa variables de entorno de la app al `dind` ni a Slim (cumple el chequeo de constitución). Solo `DOCKER_TLS_CERTDIR=` y `DOCKER_HOST`. El artefacto trae tamaños, conteos y la instrucción `CreatedBy` de la capa más grande (`cut -c1-160`), sin valores de `ENV`. En estas tres imágenes la instrucción más grande es un `RUN` o un `COPY` sin secretos.

**Riesgo relativo.** Jenkins ya monta `/var/run/docker.sock` en la etapa "Trivy imágenes" y usa `docker` en el host para construir y desplegar. Quien controla el pipeline ya tiene root en la VM de Colima. El Docker temporal no añade capacidad a quien edite el `Jenkinsfile`. Añade superficie solo ante un atacante en la red `bridge` durante la ventana del análisis.

**Conclusión.** Aceptable para este uso (taller de un solo equipo, Colima local, sin TLS ni exposición al host), con N-2, N-3 y N-4 como mejoras recomendadas. No hace falta `--privileged` en Slim ni en el resto del pipeline, y no debe extenderse a otros contenedores.

## Terceros con versión fija

| Imagen | Dónde | Versión fija | Nota |
|---|---|---|---|
| `postgres:17.11-alpine3.24` | `Jenkinsfile:17` | Sí (mayor y menor; PostgreSQL no tiene parche) | Igual al `FROM` de db |
| `python:3.13.18-slim-trixie` | `Jenkinsfile:18` | Sí | Igual al `FROM` de api |
| `ghcr.io/cirruslabs/flutter:3.44.0` | `Jenkinsfile:34` | Sí | Igual al `FROM` de web |
| `semgrep/semgrep:1.184.0` | `Jenkinsfile:49` | Sí | |
| `aquasec/trivy:0.76.2` | `Jenkinsfile:62,84` | Sí | |
| `docker:27.5.1-dind` | `scripts/slim-analysis.sh:14` | Sí | 69 CVE con parche (7 CRITICAL) en Go; la rama 27 ya no recibe parches. Solo vive unos minutos y sin red expuesta |
| `dslim/slim:1.40.11` | `scripts/slim-analysis.sh:8` | Sí | Sin mantenimiento desde 2024, solo amd64. Acceso al `dockerd` temporal, no al del host |

Las versiones fijas dejan de recibir parches de forma automática: hay que subirlas a mano. Las imágenes base propias ya traen `apk upgrade` y `apt-get upgrade` (RF-12). No añadí `@sha256`: la spec lo deja fuera (RF-7).

## Revisión de Containerfiles

| Archivo | Sin root | Secretos | `ADD` o descargas remotas | Nota |
|---|---|---|---|---|
| `api/brewtrack-api.Containerfile` | Sí, `USER app` (línea 16) | Ninguno | Ninguno | Dos etapas; `pip` y `setuptools` desinstalados |
| `web/brewtrack-web.Containerfile` | Sí, `USER nginx` (línea 18) | Ninguno | Ninguno | Dos etapas; `ENV API_UPSTREAM` es una URL interna, no un secreto |
| `db/brewtrack-db.Containerfile` | Sí, `USER postgres` (línea 6) | Ninguno | Ninguno | Una etapa, excepción D-4 |

Las tres imágenes usan `docker.io/library/...` o `ghcr.io/...` con etiqueta fija; ninguna usa `latest`. La regla `p/dockerfile` de Semgrep puede no leer archivos `*.Containerfile`; por eso la revisión manual de esta tabla.

## Falsos positivos

| Hallazgo | Herramienta | Motivo |
|---|---|---|
| 2 CRITICAL de Stripe en `docs/security/scan_semgrep.txt:17` y `:58` | Trivy fs | Es la salida guardada de un escaneo de Semgrep: el valor ya está enmascarado con asteriscos y no es una clave. El archivo sigue en `docs/security`. El `Jenkinsfile` lo excluye (`--skip-files`, línea 66). No viene de esta spec |
| 26 CVE en `usr/local/bin/gosu` (Go 1.24.6) | Trivy imagen db | Riesgo aceptado en `docs/security/2026-11-10-imagen-db.md`; el pipeline lo omite con `--skip-files usr/local/bin/gosu` (`Jenkinsfile:88`). No se puede reconstruir `gosu` sin salir de la imagen oficial |

## Deuda previa al cambio

- 47 HIGH sin parche en la base Debian 13.7 de `api` (`util-linux`, `libsqlite3-0`, `ncurses`, `perl-base` y otros). Se revisan al subir la etiqueta de `python`.
- `gosu` en `db` (26 CVE de `stdlib` de Go, uno CRITICAL, con parche en el Go de `gosu`): ya documentado.
- `docs/security/scan_semgrep.txt` sigue en el repositorio con el patrón de una clave de Stripe enmascarada.
- `docs/ci/jenkins.md`, que cita `AGENTS.md` y el `Jenkinsfile`, no existe (lo anotó el developer).
- Semgrep no entrega reglas de Dockerfile sobre `*.Containerfile`: sin cobertura automática de esos archivos.
