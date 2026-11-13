# Revisión de seguridad — rama `entregable3_DevSec`

Fecha: 2026-11-10.

Este informe junta lo que encontraron las herramientas en esta rama y lo que hicimos con cada hallazgo: lo arreglamos, era un falso positivo o aceptamos el riesgo. Fuentes:

- `Semgrep.md`: cómo corrimos Semgrep y cómo revisamos el frontend.
- `scan_semgrep.txt`: salida de Semgrep, 27 hallazgos.
- `Trivy.md`: salida de Trivy sobre las imágenes, del 2026-11-05.
- `docs/security/2026-11-10-imagen-db.md`: por qué `db` tiene imagen propia y por qué aceptamos el riesgo de `gosu`.

El 2026-11-10 volvimos a correr las dos herramientas con los mismos comandos para medir el resultado final. Esos números son los de la columna "Después".

## Resumen

| Herramienta | Qué revisa | Antes | Después |
|---|---|---|---|
| Semgrep | Código, Containerfiles, YAML de k8s, nginx, secretos | 27 hallazgos | 0 en código. Quedan falsos positivos en documentos y en `pubspec.lock` |
| Trivy `brewtrack-web` | Paquetes de Alpine | 6 (1 CRITICAL, 5 HIGH) | 0 |
| Trivy `brewtrack-api` | Paquetes de Debian | 48 HIGH | 47 HIGH, ninguno tiene arreglo publicado |
| Trivy `brewtrack-api` | Paquetes de Python | 5 HIGH | 0 |
| Trivy `brewtrack-db` | Paquetes de Alpine | 18 HIGH | 0 |
| Trivy `brewtrack-db` | Binario `gosu` (Go) | 26 (1 CRITICAL, 25 HIGH) | 26, riesgo aceptado |
| `flutter pub outdated` | Dependencias de Dart | Riverpod 2 desactualizado | Riverpod 3 |

Trivy se corrió con `--severity HIGH,CRITICAL`.

## 1. Semgrep

Comando (en `Semgrep.md`): reglas de la comunidad (`semgrep-rules`) para `python`, `dockerfile`, `yaml`, `generic/nginx` y `generic/secrets`, sin `.venv`, `web/build` ni `.pubcache`.

### 1.1 Kubernetes: contenedores sin `securityContext` — arreglado

**Hallazgo.** Doce avisos en cuatro contenedores: `postgres` y `api` en `k8s/brewtrack.yaml`, y `web` azul y verde en `k8s/web-bluegreen.yaml`. Cada uno tenía tres avisos:

- `run-as-non-root`: el contenedor podía correr como root.
- `allow-privilege-escalation-no-securitycontext`: un binario `setuid` podía subir privilegios.
- `writable-filesystem-container`: la raíz del contenedor se podía escribir, así que un atacante podía bajar y correr código.

**Qué hicimos.**

- **Pod:** `securityContext` con `runAsNonRoot: true` y un uid numérico.
  - `postgres` corre con el uid 70 y `fsGroup: 70`, para que pueda escribir en el disco.
  - `api` corre con el uid 1000.
  - `web` corre con el uid 101.
  - El uid tiene que ser un número: con `USER app` el kubelet no puede comprobar `runAsNonRoot`.
- **Contenedor:** `allowPrivilegeEscalation: false` y `readOnlyRootFilesystem: true`.
- **Carpetas que cada proceso necesita escribir:** discos en memoria (`emptyDir`).
  - `postgres`: `/var/run/postgresql` y `/tmp`.
  - `api`: `/tmp`.
  - `web`: `/etc/nginx/conf.d`, `/var/cache/nginx` y `/tmp`.

### 1.2 nginx: `proxy_set_header Host $host` — arreglado

**Hallazgo.** `request-host-used` en `web/templates/default.conf.template:13`. `$host` sale de la cabecera `Host` que manda el cliente, así que un atacante puede poner ahí lo que quiera y nginx se lo pasa a la API.

**Qué hicimos.** Borramos la línea. nginx manda ahora su valor por defecto, el host de `proxy_pass` (`api:8000`). La API no usa `Host` para nada, así que no cambia su comportamiento.

### 1.3 `api/app/errors.py`: funciones internas "sin usar" — falso positivo, pero cambiamos el código

**Hallazgo.** Tres `useless-inner-function` para `_api`, `_http` y `_validation`.

**Por qué es falso positivo.** Esas funciones sí se usan: el decorador `@app.exception_handler(...)` las registra. Semgrep no ve ese uso.

**Qué hicimos igual.** Sacamos las funciones fuera de `install()` y las registramos con `app.add_exception_handler(...)`. El comportamiento no cambia y Semgrep ya no avisa, así el informe queda limpio. Para comprobar que el formato de error sigue siendo `{"error": {"code", "message"}}`, `api/tests/test_roasts.py` revisa ahora el texto exacto de dos errores 422.

### 1.4 Secretos en los documentos de las skills — falso positivo

**Hallazgo.** Siete avisos (`generic-api-key` y `stripe-access-token`) en `.agents/skills/code-security/` y `.agents/skills/llm-security/`.

**Por qué es falso positivo.** Son ejemplos de lo que *no* hay que hacer, escritos en guías de seguridad: `stripe('sk_test_…')`, `API Key: sk-abc123…` y un `PASSWORD` en base64 dentro de un `Secret` de ejemplo. No son claves de BrewTrack ni de ningún servicio real.

**Qué hicimos.** Nada en el código. Si queremos que el informe salga limpio, el próximo escaneo puede excluir esas carpetas con `--exclude .agents`.

### 1.5 `web/pubspec.lock`: "token de Facebook" — falso positivo

**Hallazgo.** `facebook-page-access-token` en la línea 172.

**Por qué es falso positivo.** Es el hash `sha256` con el que pub comprueba que el paquete bajado no cambió. La regla confunde la cadena hexadecimal larga con un token.

**Qué hicimos.** Nada. `pubspec.lock` tiene que estar así.

### 1.6 `scan_semgrep.txt` — falso positivo nuevo

Al volver a escanear, Semgrep marca 11 "secretos" en `scan_semgrep.txt`. Son los mismos falsos positivos de 1.4 y 1.5, copiados dentro de la salida del escaneo anterior. Desaparecen si el archivo se excluye del escaneo o no se guarda en el repo.

### 1.7 Frontend (Dart)

Semgrep no tiene reglas para Dart. En su lugar usamos `flutter analyze` y `flutter pub outdated`. Con `flutter pub upgrade --major-versions` subimos `flutter_riverpod` de 2.6 a 3.4. Riverpod 3 marca `valueOrNull` como obsoleto, así que pasamos a `value`, que devuelve `null` mientras carga o si hay error. Lo cambiamos en `lot_detail_screen.dart`, `roast_detail_screen.dart`, `roasts_screen.dart`, `router.dart`, `shell.dart` y `stats_screen.dart`.

## 2. Trivy

Comando: `trivy image --severity HIGH,CRITICAL` sobre cada imagen de `docker compose config --images`.

### 2.1 `brewtrack-web` (nginx sobre Alpine) — arreglado

**Hallazgo.** Seis fallos, todos con versión corregida en Alpine:

| Paquete | CVE | Nivel | Corregido en |
|---|---|---|---|
| brotli-libs | CVE-2026-111497 | CRITICAL | 1.2.1-r0 |
| curl, libcurl | CVE-2026-92392 | HIGH | 8.23.0-r0 |
| libexpat | CVE-2026-113351, CVE-2026-117610, CVE-2026-118370 | HIGH | 2.10.0-r0 |

**Qué hicimos.** `apk upgrade --no-cache` en `web/brewtrack-web.Containerfile`, antes de pasar a `USER nginx`. Al volver a escanear: 0.

### 2.2 `brewtrack-api` (Python 3.13 sobre Debian 13)

**Paquetes de Python — arreglado.** Cinco HIGH:

| Paquete | CVE | Corregido en |
|---|---|---|
| msgpack 1.1.2 | CVE-2026-114613, GHSA-6v7p-g79w-8964 | 1.2.3 |
| setuptools 70.3.0 | CVE-2025-47273 | 78.1.1 |
| urllib3 2.7.0 | CVE-2026-97687, CVE-2026-97689 | 2.8.0 |

Ninguno es dependencia de BrewTrack: los trae `pip` dentro de la imagen base. La API no necesita `pip` para funcionar, así que lo quitamos en la etapa final (`pip uninstall -y pip setuptools` en `api/brewtrack-api.Containerfile`). Al volver a escanear: 0.

**Paquetes de Debian — arreglado en parte, el resto es riesgo aceptado.**

- Agregamos `apt-get upgrade -y` al construir. Así se corrigió `apt` y `libapt-pkg7.0` (CVE-2026-109518, corregido en 3.0.4).
- Quedan 47 HIGH. Todos figuran como `affected` o `fix_deferred`, es decir, Debian todavía no publicó arreglo y no hay versión a la que subir:
  - `util-linux` y sus bibliotecas (`bsdutils`, `libblkid1`, `libmount1`, `libuuid1`, `libsmartcols1`, `liblastlog2-2`, `login`, `mount`): CVE-2026-76642, CVE-2026-78408, CVE-2026-78409 y CVE-2026-78410.
  - `ncurses` (`libncursesw6`, `libtinfo6`, `ncurses-base`, `ncurses-bin`): CVE-2025-69720.
  - `libsqlite3-0`: CVE-2026-119373, CVE-2026-119374 y CVE-2026-119379.
  - `libsystemd0` y `libudev1`: CVE-2026-16742.
  - `libacl1`: CVE-2026-54369.
  - `zlib1g`: CVE-2026-76844. Salía en el escaneo del 2026-11-05 y no salió en el nuevo.
  - `perl-base`: CVE-2026-9538, con `fix_deferred`.

**Por qué aceptamos ese riesgo.**

- Nadie puede corregirlos hoy: Debian no publicó versión arreglada.
- La API no llama a esas herramientas (`mount`, `login`, `perl`). La API usa PostgreSQL, no SQLite.
- El proceso corre como `app` (uid 1000), no como root. En k8s además tiene la raíz de solo lectura y no puede subir privilegios (1.1).
- Se cierran solos: la próxima vez que se construya con `docker compose build --pull api` después de que Debian publique el arreglo, `apt-get upgrade` lo instala.

### 2.3 `brewtrack-db` (PostgreSQL 17 sobre Alpine)

**Paquetes de Alpine — arreglado.** La imagen oficial `postgres:17-alpine` traía 18 HIGH (entre ellos krb5 y libxslt), todos con versión corregida en Alpine. Creamos `db/brewtrack-db.Containerfile`: la imagen oficial más `apk upgrade --no-cache`. `compose.yaml` y `k8s/brewtrack.yaml` usan ahora `localhost/brewtrack-db:0.1.0`. El volumen `pgdata` no cambia, porque es el mismo PostgreSQL 17. Al volver a escanear: 0.

**`gosu` — riesgo aceptado.** `gosu` 1.19 está compilado con Go 1.24.6 y Trivy marca 26 fallos en la biblioteca estándar de Go. El CRITICAL es CVE-2025-68121, en `crypto/tls`. No lo arreglamos porque:

- `gosu` solo cambia de usuario al arrancar y termina con `exec`. No abre conexiones, así que el código de TLS, HTTP y x509 de Go nunca corre.
- En compose, PostgreSQL corre como `postgres` (lo comprobamos con `ps`). En k8s el pod ya arranca con el uid 70 y no llama a `gosu`.
- `db` no publica puertos: solo le habla `api` por la red interna.
- Quitar `gosu` obliga a cambiar cómo arranca PostgreSQL en compose y a revisar los permisos del volumen. Cuesta más de lo que protege.

Se cierra cuando la imagen oficial traiga un `gosu` compilado con un Go corregido. Para comprobarlo:

```sh
docker compose build --pull db && trivy image --severity HIGH,CRITICAL localhost/brewtrack-db:0.1.0
```

Más detalle en `docs/security/2026-11-10-imagen-db.md`.

## 3. Otras decisiones de seguridad de esta rama

### 3.1 Admin inicial sin credenciales fijas

Para agilizar el desarrollo se pidió un admin `admin@admin.com` con contraseña `admin` escrito en el código de la carga de ejemplo. No lo hicimos así porque:

- rompe la regla de la constitución: todo secreto entra por variable de entorno;
- `create-admin` exige al menos 8 caracteres;
- Semgrep lo marcaría como credencial escrita en el código;
- cualquiera que tenga la imagen conocería la contraseña.

En su lugar, la API crea el admin desde `.env` (`SEED_ADMIN_EMAIL` y `SEED_ADMIN_PASSWORD`), y solo si la base no tiene usuarios. Si la contraseña tiene menos de 8 caracteres, la API no arranca, y el mensaje de error no muestra la contraseña. La contraseña tampoco aparece en el log, y hay tests que lo comprueban (`api/tests/test_seed.py` y `api/tests/test_config.py`). Spec: `specs/006-admin-inicial-desde-entorno/spec.md`.

### 3.2 Puertos

`web` publica ahora el 8081 en lugar del 8080, para no chocar con Jenkins. Solo `web` publica puerto. `db` y `api` siguen sin puertos abiertos al host. La tabla de puertos está en `AGENTS.md`.

## 4. Pendientes

| Pendiente | Cuándo se cierra |
|---|---|
| 47 HIGH de Debian en `brewtrack-api` | Cuando Debian publique el arreglo. Reconstruir con `--pull`. |
| 26 de `gosu` en `brewtrack-db` | Cuando la imagen oficial de postgres traiga un `gosu` compilado con un Go corregido. |
| Parches que envejecen | `apk upgrade` y `apt-get upgrade` toman los parches del día en que se construye. Reconstruir las imágenes con `--pull` cada tanto y volver a correr Trivy. |
| Falsos positivos de Semgrep | Excluir `.agents` y `scan_semgrep.txt` del escaneo, o anotarlos como aceptados. |
