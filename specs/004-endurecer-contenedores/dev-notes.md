# Notas del traspaso 004

## Qué cambió
- `web/brewtrack-web.Containerfile`: `USER nginx`, pid en `/tmp`, `chown` de caché y `conf.d`. Base sigue en `nginx:alpine`.
- `web/templates/default.conf.template`: `listen 8080`.
- `compose.yaml`: `8080:8080`.
- `api/app/config.py`: el secreto exige 32 caracteres o más y no puede ser el de la plantilla. Un fallo de configuración termina con un mensaje sin valores.
- `api/tests/test_config.py`: tests nuevos.
- `.env.example` y `README.md`: mínimo, comando `openssl rand -hex 32` y aviso a instalaciones existentes.

## Cómo probar
- `cd api && pytest` (con el Postgres de pruebas en el puerto 55432).
- `podman compose up --build -d`; luego `podman compose exec web ps -o user,pid,args` y `podman compose exec web id -u`.
- `JWT_SECRET=corto python -c "import app.main"` termina con código 1.

## Cómo comprobé RF-1
Usuario `nginx` (UID 101), puerto 8080. `ps` en el contenedor muestra el maestro (PID 1) y todos los workers como `nginx`; `id -u` da 101. Los logs de `web` no muestran avisos ni errores de permisos.

## Pendiente
Los hallazgos 2, 3 y 5 a 11 siguen fuera de alcance. Tras reiniciar `api`, la web vuelve a responder 200 sin reiniciar `web`.

## Preguntas abiertas
Ninguna.
