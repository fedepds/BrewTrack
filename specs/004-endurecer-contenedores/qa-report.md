# Informe de QA — spec 004

Rama: `feat/004-endurecer-contenedores`. Fecha: 2026-10-15.

## Veredicto: APROBADO

Los 14 criterios pasan. No hay violaciones de la constitución ni fallos.

## Criterios de aceptación

| CA | Resultado | Evidencia |
|---|---|---|
| CA-1 | Pasa | `exec web ps -o user,pid,args`: maestro (PID 1) y 5 workers con usuario `nginx`. Ningún proceso `root`. |
| CA-2 | Pasa | `exec web id -u` da 101. |
| CA-3 | Pasa | `GET :8080/api/v1/health` 200 `{"status":"ok"}`. `GET :8080/lotes` 200 con `index.html`. |
| CA-4 | Pasa | Con token: 200, `limit` 5, `offset` 0, `total` 20. Sin token: 401 `{"error":{"code":"unauthorized","message":...}}`. |
| CA-5 | Pasa | `restart api` sin tocar `web`: `/api/v1/health` 200 en el segundo intento (el primero, durante el arranque, dio conexión rechazada). |
| CA-6 | Pasa | `compose ps`: solo `web` publica `0.0.0.0:8080->8080`. `api` y `db` solo exponen puertos internos. |
| CA-7 | Pasa | 31 caracteres: salida 1; "JWT_SECRET tiene menos de 32 caracteres". |
| CA-8 | Pasa | Valor de plantilla: salida 1; "JWT_SECRET es el valor de la plantilla .env.example". |
| CA-9 | Pasa | Ningún fragmento de 8 caracteres del valor en stdout ni stderr (prueba manual y `test_config.py`). |
| CA-10 | Pasa | Secreto de 32 caracteres: arranca (salida 0). En el stack, login con admin de prueba devuelve tokens y `/health` da 200. |
| CA-11 | Pasa | `security-report.md`: APROBADO, sin bloqueantes, DS-0002 ausente. No repetí las herramientas. |
| CA-12 | Pasa | `pytest`: 107 pasan. `flutter test`: 15 pasan. `flutter analyze`: sin problemas. |
| CA-13 | Pasa | `.env.example` (líneas 2-4) y `README.md` (líneas 29 y 31): mínimo 32, `openssl rand -hex 32`, aviso de que la API no arranca y de que los usuarios vuelven a entrar. |
| CA-14 | Pasa | La etapa final parte de `docker.io/library/nginx:alpine`. |

## Constitución

| Regla | Resultado | Evidencia |
|---|---|---|
| Sin columna de stock | Pasa | El diff no toca `models.py` ni migraciones. |
| Permisos impuestos en la API | Pasa | No hay endpoints nuevos. Sin token, `/green-lots` da 401. |
| Formato de error | Pasa | 401 con `{"error": {"code", "message"}}` a través del proxy. El fallo de arranque no es HTTP, como dice la spec. |
| Migración nueva, idempotente | No aplica | No cambia el esquema. `alembic upgrade head` corrió limpio en la base vacía del stack, dos veces (arranque y reinicio de `api`). |
| Sin credenciales ni `.env` | Pasa | No leí `.env`. Los secretos entraron por entorno. `.env.example` solo trae valores de ejemplo. Semgrep y Trivy sin secretos, según `security-report.md`. |
| Imagen `api` sin root y `/health` | Pasa | El cambio no toca el usuario `app`. `/health` responde 200 en el stack. |
| Sin nada fuera de alcance | Pasa | Solo endurece `web` y la configuración de la API. |
| Base `nginx:alpine` | Pasa | CA-14. |
| Idioma de los comentarios | Pendiente de revisión humana | Aprueba el PR Federico Pizarro. Los comentarios nuevos están en español; el código, en inglés. |

## Fallos

Ninguno.

## Criterios sin prueba

- Ninguno. CA-11 se apoya en `security-report.md`; no volví a ejecutar las herramientas.
- Casos límite del flujo de tuestes (stock, 409, último admin y similares): no cambian en esta spec. Los cubre la suite de pytest, que pasa.

## Seguridad

Veredicto de `security-report.md`: APROBADO. Bloqueantes resueltos desde la auditoría inicial: Hallazgo 1 (DS-0002, imagen `web` sin `USER`) y Hallazgo 4 (`JWT_SECRET` sin mínimo). Quedan los hallazgos 2, 3 y 5 a 11, fuera de alcance de la spec.

## Notas

- El Postgres de pruebas y el stack (`-p qa004`, `down -v`) están borrados.
- Nota menor: la imagen `web` declara también `80/tcp` (viene de `nginx:alpine`). Nginx solo escucha en 8080.
