# 006 — Admin inicial desde el entorno

Estado: aprobada
Fecha: 2026-11-10

## Contexto y objetivo

Hasta ahora, en una base nueva, nadie podía entrar a BrewTrack hasta que alguien ejecutaba `create-admin` dentro del contenedor `api`. Había que repetir ese paso en cada instalación y cada vez que se borraba el volumen `pgdata`.

El usuario pidió que la carga de ejemplo cree un admin `admin@admin.com` con contraseña `admin`, fija en el código. Eso chocaba con dos reglas:

- la constitución exige que todo secreto entre por variable de entorno;
- `create-admin` exige contraseñas de 8 caracteres o más, y `admin` tiene 5.

El usuario eligió que el email y la contraseña del primer admin vengan de `.env`, y que ese sea el camino principal (D-1). La constitución ya lo recoge.

Objetivo: al levantar el stack sobre una base sin usuarios, la API crea el primer admin con el email y la contraseña de `.env`. Así se entra en http://localhost:8080 sin ejecutar `create-admin`. Si `.env` deja las variables vacías, la API no crea ningún usuario y el primer admin se crea con `create-admin`.

## Historias de usuario

- HU-1. Como `admin`, quiero que una base nueva arranque con mi usuario admin ya creado, para entrar sin ejecutar `create-admin`, también cada vez que borro la base.
- HU-2. Como `admin`, quiero que los tuestes de ejemplo de la spec 002 aparezcan en ese mismo arranque, para ver datos desde el primer login.
- HU-3. Como `admin`, quiero que la API no cree ningún usuario si dejo las variables vacías, para crear el primer admin con `create-admin` si lo prefiero.
- HU-4. Como `admin`, quiero que la API se niegue a arrancar con una contraseña corta, para que nadie entre con una contraseña más débil que las que acepta `create-admin`.

## Requisitos funcionales

### Variables

- RF-1. Dos variables de entorno nuevas: `SEED_ADMIN_EMAIL` y `SEED_ADMIN_PASSWORD`. Si no están definidas, valen vacío.
- RF-2. `compose.yaml` pasa las dos variables al servicio `api`. Si `.env` no las define, llegan vacías.
- RF-3. `.env.example` documenta las dos variables con un comentario que dice:
  - que sirven para crear el primer admin;
  - que el admin se crea solo si están las dos y la base no tiene usuarios;
  - que la contraseña necesita 8 caracteres o más;
  - que, si quedan vacías, el primer admin se crea con `create-admin`.

  En `.env.example`, `SEED_ADMIN_EMAIL` vale `admin@admin.com` y `SEED_ADMIN_PASSWORD` queda vacía. La plantilla no trae ninguna contraseña.

### Validación al arrancar

- RF-4. Si `SEED_ADMIN_PASSWORD` no está vacía y tiene menos de 8 caracteres, la API no arranca. La salida dice "SEED_ADMIN_PASSWORD tiene menos de 8 caracteres" y no muestra el valor de la variable. Pasa lo mismo aunque `SEED_ADMIN_EMAIL` esté vacía.
- RF-5. El mínimo de 8 caracteres es el mismo de `create-admin`. Si uno cambia, cambia el otro.

### Cuándo se crea el admin

- RF-6. La API intenta crear el admin al arrancar, antes de cargar los lotes y tuestes de ejemplo de la spec 002.
- RF-7. El admin se crea solo si se cumplen las dos condiciones:
  - `SEED_ADMIN_EMAIL` y `SEED_ADMIN_PASSWORD` tienen valor;
  - la base no tiene ningún usuario, activo o inactivo.
- RF-8. Si falta una de las dos variables, la API no crea ningún usuario y no escribe ninguna línea sobre el admin inicial.
- RF-9. Si la base ya tiene al menos un usuario, la API no crea ni cambia ningún usuario. Tampoco cambia la contraseña de un admin que ya existe, aunque `SEED_ADMIN_PASSWORD` cambie.
- RF-10. La creación del admin no depende de `SEED_DEMO_LOTS`. Con `SEED_DEMO_LOTS=false`, el admin se crea igual.

### Qué se crea

- RF-11. El usuario creado tiene:
  - email: el valor de `SEED_ADMIN_EMAIL` sin espacios al principio ni al final y en minúsculas, con la misma regla que aplica `POST /api/v1/auth/login` (D-2);
  - nombre: `admin`;
  - rol: `admin`;
  - estado: activo;
  - contraseña: la de `SEED_ADMIN_PASSWORD`, guardada con argon2, como en `create-admin`.
- RF-12. El usuario creado entra con `POST /api/v1/auth/login` y se comporta como cualquier admin: mismos endpoints y permisos.
- RF-13. En una base nueva con `SEED_DEMO_LOTS=true`, el admin inicial existe antes de la carga de tuestes. Por la regla RF-10 de la spec 002 (el autor es el usuario activo más antiguo), ese admin es el autor de los 24 tuestes de ejemplo, y los tuestes se cargan en ese mismo arranque.

### Log

- RF-14. La API escribe una línea con el resultado:
  - "Se creó el admin inicial " seguido del email de RF-11;
  - "Carga del admin inicial omitida: la base ya tiene usuarios".
- RF-15. Si la creación falla, la base queda sin ese usuario, el error queda en el log y la API arranca igual, como las cargas de la spec 002.
- RF-16. Ninguna línea del log ni de la salida de la API muestra el valor de `SEED_ADMIN_PASSWORD`.

### `create-admin`

- RF-17. `create-admin` no cambia y queda como alternativa. No lee `SEED_ADMIN_EMAIL` ni `SEED_ADMIN_PASSWORD` y nunca crea el admin inicial.

## Criterios de aceptación

CA-1 a CA-8 son pruebas de la API (`cd api && pytest`). CA-9 es una prueba manual de QA sobre el stack.

- CA-1. Dada una base sin usuarios, `SEED_ADMIN_EMAIL=" Admin@Admin.com "` (con espacios) y `SEED_ADMIN_PASSWORD=longenough1`, cuando la API arranca, entonces:
  - la base tiene un usuario con email `admin@admin.com`, nombre `admin` y rol `admin`;
  - el log contiene "Se creó el admin inicial admin@admin.com";
  - `POST /api/v1/auth/login` con `admin@admin.com` y esa contraseña responde 200.

  Prueba: `test_admin_seed_creates_admin_who_can_log_in`.
- CA-2. Dada una base nueva, `SEED_DEMO_LOTS=true` y las dos variables de CA-1, cuando la API arranca, entonces en ese arranque se cargan los 24 tuestes de ejemplo y el autor de todos es el admin inicial. Prueba: `test_admin_seed_is_author_of_demo_roasts`.
- CA-3. Dada una base sin usuarios y las dos variables de CA-1, cuando la API arranca, entonces el log no contiene `longenough1`. Prueba: `test_admin_seed_log_hides_password`.
- CA-4. Dada una base con un usuario `roaster` y las dos variables de CA-1, cuando la API arranca, entonces la base sigue con un solo usuario, ese `roaster`, y el log contiene "Carga del admin inicial omitida: la base ya tiene usuarios". Prueba: `test_admin_seed_skipped_when_users_exist`.
- CA-5. Dada una base sin usuarios, `SEED_ADMIN_EMAIL=admin@admin.com` y `SEED_ADMIN_PASSWORD` vacía, cuando la API arranca, entonces la base sigue sin usuarios. Prueba: `test_admin_seed_off_without_password`.
- CA-6. Dada una base sin usuarios, `SEED_ADMIN_PASSWORD=longenough1` y `SEED_ADMIN_EMAIL` vacía, cuando la API arranca, entonces la base sigue sin usuarios. Prueba: `test_admin_seed_off_without_email`.
- CA-7. Dados `SEED_ADMIN_EMAIL=admin@admin.com` y `SEED_ADMIN_PASSWORD=admin`, cuando la API arranca, entonces termina con código distinto de 0, la salida nombra `SEED_ADMIN_PASSWORD` y el mínimo de 8, y no muestra el valor recibido. Prueba: `test_short_seed_admin_password_is_rejected`.
- CA-8. Dado el código de la entrega, cuando se ejecuta `cd api && pytest`, entonces pasan los tests que ya existían de `create-admin` y de la spec 002, sin cambios en lo que comprueban.
- CA-9. Dados un volumen `pgdata` nuevo y un `.env` con `SEED_ADMIN_EMAIL=admin@admin.com`, una `SEED_ADMIN_PASSWORD` de 8 caracteres o más y `SEED_DEMO_LOTS` sin definir, cuando QA ejecuta `docker compose up --build -d` y entra en http://localhost:8080 con esas credenciales, sin ejecutar `create-admin`, entonces entra como admin, ve la pantalla de Usuarios y la de tuestes muestra 24 tuestes. Cuando QA ejecuta `docker compose logs api`, entonces la contraseña no aparece.

## Chequeo de constitución

- **Alcance:** aplica. Solo crea un usuario `admin` del mismo taller. No toca curvas, empaque, venta, recetas, cata ni multi-empresa.
- **Stock calculado:** no aplica. No cambia lotes ni tuestes. Los tuestes de ejemplo siguen las reglas de stock de la spec 002.
- **Permisos en la API:** aplica. No hay endpoints nuevos ni auto-registro: la API crea el admin al arrancar, con datos que pone quien controla `.env`. Ningún cliente puede dispararlo. El admin creado tiene los mismos permisos que cualquier admin (RF-12). La constitución dice ahora que el primer admin sale de `.env` y que `create-admin` queda como alternativa (D-1).
- **Formato de error:** no aplica. No hay respuestas nuevas. El login del admin usa `POST /api/v1/auth/login`, que ya responde los errores con `{"error": {"code", "message"}}`.
- **Migraciones:** no aplica. No cambia el esquema.
- **Secretos:** aplica. La contraseña entra solo por variable de entorno (RF-1). No hay credenciales fijas en el código. `.env.example` no trae contraseña (RF-3). Ni el log ni el error de arranque muestran el valor (RF-4, RF-16, CA-3, CA-7, CA-9).

## Fuera de alcance

- Kubernetes: `k8s/brewtrack.yaml` no define las variables, así que en ese despliegue no se crea el admin inicial.
- Cambiar la contraseña o los datos de un admin que ya existe desde el entorno.
- Credenciales fijas en el código, como `admin@admin.com` / `admin`.
- Crear más de un usuario, o usuarios `roaster`, desde el entorno.
- Validar el formato del email más allá de quitar espacios y pasarlo a minúsculas.
- Cambios en `create-admin` o en la interfaz Flutter. Por eso esta spec no pide pruebas de widgets.

## Decisiones

- D-1. **Primer admin desde `.env`** (resuelve P-1). El usuario eligió el 2026-11-10 que el primer admin salga de `.env` y que `create-admin` quede como alternativa. La constitución (`docs/superpowers/specs/2026-10-07-brewtrack-design.md`, sección Auth y "Contenedores y estructura") ya lo dice. `AGENTS.md`, `README.md` y `.env.example` presentan `.env` como el camino principal.
- D-2. **Email normalizado como en el login** (resuelve P-2). La API quita los espacios del principio y del final de `SEED_ADMIN_EMAIL` y lo pasa a minúsculas, igual que `POST /api/v1/auth/login`. CA-1 lo prueba con `" Admin@Admin.com "`.
- D-3. **Pruebas completas** (resuelve P-3). `test_admin_seed_is_author_of_demo_roasts` comprueba el autor de los 24 tuestes (CA-2). Hay dos pruebas nuevas: `test_admin_seed_log_hides_password` (CA-3) y `test_admin_seed_off_without_email` (CA-6).

## Preguntas abiertas

Ninguna. P-1, P-2 y P-3 de la versión 0.1 pasan a "Decisiones" (D-1 a D-3).

## Historial

| Fecha | Versión | Cambio |
|---|---|---|
| 2026-11-10 | 0.1 | Borrador que documenta un cambio ya implementado. El usuario pidió un admin `admin@admin.com` / `admin` fijo en el código; se le explicó el choque con la regla de secretos y con el mínimo de 8 caracteres, y eligió que el admin venga de `.env`. El código se escribió antes de esta spec, en contra del flujo SDD ("nada se implementa sin spec aprobada"). Quedan abiertas P-1 a P-3. |
| 2026-11-10 | 1.0 | Spec aprobada. El usuario resuelve P-1: el primer admin sale de `.env` y `create-admin` queda como alternativa; la constitución ya lo dice (D-1). Los textos dejan de presentar `.env` como un camino solo para desarrollo. P-2: el email se normaliza como en el login (RF-11, D-2). P-3: se amplía la prueba de CA-2 y se agregan CA-3 y CA-6 con sus pruebas (D-3). Los criterios se renumeran: CA-3 a CA-7 de la 0.1 pasan a CA-4, CA-5, CA-7, CA-8 y CA-9. Sigue pendiente pasar por seguridad y QA. |
