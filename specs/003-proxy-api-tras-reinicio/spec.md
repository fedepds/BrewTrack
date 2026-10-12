# 003 — La web sigue llegando a la API tras reiniciar `api`

Estado: aprobada
Fecha: 2026-10-12

## Contexto y objetivo

QA encontró el fallo al probar la spec 002 (observación 4 de su informe). Después de `podman compose restart api`, la web responde 502 en todo `/api/` hasta que alguien reinicia también `web`.

La causa: nginx resuelve el nombre `api` una sola vez, al arrancar, y sigue usando esa IP. Al reiniciar, `api` recibe otra IP (QA vio 10.89.11.3 antes y 10.89.11.6 después).

Objetivo: que la web vuelva a llegar a la API cuando `api` se reinicia, sin tocar `web`.

## Historias de usuario

- HU-1. Como `admin`, quiero reiniciar solo `api` y que la interfaz siga funcionando, para no tener que reiniciar el stack entero.

## Requisitos funcionales

- RF-1. Después de reiniciar `api`, `web` vuelve a enviar las peticiones de `/api/` a la API, aunque `api` tenga otra IP. No hace falta reiniciar `web`.
- RF-2. El proxy de `/api/` no cambia en nada más: la misma ruta, la misma query y las mismas cabeceras llegan a la API que antes.
- RF-3. El mecanismo debe funcionar con el DNS de la red de Podman. Ese DNS no siempre está en `127.0.0.11`, así que no se puede fijar una dirección a mano sin probarla. El developer elige el mecanismo y documenta en `dev-notes.md` cómo lo probó.
- RF-4. La SPA sigue igual: cualquier ruta fuera de `/api/` sirve `index.html`.

## Criterios de aceptación

Pruebas manuales de QA sobre el stack levantado con `podman compose up --build -d`.

- CA-1. Dado el stack sano, cuando se ejecuta `podman compose restart api` y `api` vuelve a estar sano, entonces `GET http://localhost:8080/api/v1/health` responde 200 sin reiniciar `web`.
- CA-2. Dado CA-1, cuando se repite `podman compose restart api` dos veces más, entonces `/api/v1/health` responde 200 a través de `web` después de cada reinicio.
- CA-3. Dado el stack de CA-1 y un usuario con sesión, cuando pide `GET http://localhost:8080/api/v1/green-lots?limit=5&offset=0`, entonces recibe 200 con `limit` 5 y `offset` 0 en el cuerpo. Esto prueba que la ruta y la query llegan intactas.
- CA-4. Dado un cliente sin token, cuando pide `GET http://localhost:8080/api/v1/green-lots`, entonces recibe 401 con el cuerpo `{"error": {"code", "message"}}`, igual que antes del cambio.
- CA-5. Dado el stack, cuando se pide `http://localhost:8080/lotes` (o cualquier ruta de la SPA), entonces responde 200 con `index.html`.
- CA-6. Dado el stack, entonces `cd web && flutter test` y `cd api && pytest` pasan igual que antes.

## Chequeo de constitución

- **Alcance:** aplica. Solo corrige el proxy del taller. No toca datos ni funciones.
- **Stock calculado:** no aplica. No cambia ningún cálculo.
- **Permisos en la API:** aplica. La API sigue imponiendo los permisos; el proxy solo reenvía. CA-4 lo verifica.
- **Formato de error:** aplica. Los errores de la API llegan sin cambios (CA-4). Mientras `api` arranca, nginx puede responder un 502 propio; eso ya pasaba y no forma parte de esta spec.
- **Migraciones:** no aplica. No cambia el esquema.
- **Secretos:** no aplica. No entra ninguna variable nueva ni se toca `.env`.

## Fuera de alcance

- Cambiar el 502 de nginx mientras `api` arranca por una respuesta con `{"error": {"code", "message"}}`.
- Cambios en la API, en el frontend Flutter o en `compose.yaml` que no exija el arreglo.
- Pruebas automáticas del stack de contenedores (la constitución deja fuera CI/CD).

## Preguntas abiertas

Ninguna.

## Historial

| Fecha | Versión | Cambio |
|---|---|---|
| 2026-10-12 | 1.0 | Versión inicial a partir de la observación 4 del informe de QA de la spec 002. Aprobada: el usuario pidió el arreglo y el alcance es acotado. |
