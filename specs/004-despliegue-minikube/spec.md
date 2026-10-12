# 004 — Despliegue en Minikube

Estado: aceptada
Fecha: 2026-10-12

## Contexto y objetivo

La persona usuaria quiere correr BrewTrack en Minikube (Kubernetes local), además de `podman compose`. La constitución ya suma Minikube como destino adicional, en el namespace `brewtrack`. Compose sigue siendo el destino principal.

Antecedentes, hechos fuera de spec y a pedido de la persona:
- Los Containerfiles se llaman `api/brewtrack-api.Containerfile` y `web/brewtrack-web.Containerfile`.
- `compose.yaml` fija las imágenes `localhost/brewtrack-api:0.1.0` y `localhost/brewtrack-web:0.1.0`.
- Un primer intento con `podman kube generate` (archivo `manifest.yaml` en la raíz) ponía los tres contenedores en un solo Pod. Ahí `api` caía con `failed to resolve host 'db'`, porque en un Pod los contenedores comparten `localhost` y el host `db` no existe. Además traía los secretos en claro y un `hostPort: 8080` que no llega al host macOS. La persona ya borró ese archivo.

La persona eligió un Deployment y un Service por pieza (`db`, `api`, `web`), para que `db` y `api` sean nombres reales dentro del clúster.

Un detalle obliga a tocar `web`: el `resolver` de nginx (spec 003) no aplica los dominios de búsqueda de `/etc/resolv.conf`. En Kubernetes, nginx necesita el nombre completo `api.brewtrack.svc.cluster.local`. Con compose, `api` sigue bastando.

Objetivo: que la persona pueda desplegar BrewTrack en su Minikube con unos pocos comandos documentados, sin secretos en el repositorio y sin romper compose.

**Restricción de la persona:** ella crea los recursos en su clúster (`kubectl apply`, `kubectl create`, `minikube image load`). Developer y QA no le dejan nada creado. Solo QA crea el namespace `brewtrack` durante su prueba y lo borra al terminar (RF-18).

## Historias de usuario

- HU-1. Como `admin`, quiero desplegar BrewTrack en Minikube con comandos documentados, para probarlo en Kubernetes sin depender de compose.
- HU-2. Como `admin`, quiero que los secretos entren al clúster desde mi `.env`, para no escribirlos en ningún archivo versionado.
- HU-3. Como `admin`, quiero que `podman compose up --build -d` siga funcionando igual que hoy, para no perder mi forma habitual de trabajar.
- HU-4. Como `roaster`, quiero usar la interfaz servida desde Minikube igual que desde compose, para trabajar sin notar la diferencia.

## Requisitos funcionales

Host de la API en nginx
- RF-1. La imagen `web` toma el host de la API de una variable de entorno. Sin la variable, usa `api`. El developer elige el nombre de la variable y lo documenta.
- RF-2. El resto del proxy no cambia: puerto 8000, resolución dinámica de la spec 003, ruta, query y cabeceras.

Manifiestos
- RF-3. El repositorio trae manifiestos versionados para Minikube con un Deployment y un Service por pieza: `db`, `api` y `web`. El developer elige la ruta.
- RF-4. Los manifiestos usan las mismas imágenes y etiquetas que `compose.yaml`. Si la imagen `web` cambia por RF-1, cambia también su etiqueta en ambos sitios (el developer propone el valor). Los Pods arrancan con las imágenes cargadas con `minikube image load`, sin intentar descargarlas.
- RF-5. Los manifiestos incluyen el objeto `Namespace` `brewtrack`, y todos los demás objetos fijan `namespace: brewtrack`. El manifiesto de `web` fija la variable de RF-1 en el valor `api.brewtrack.svc.cluster.local`. `web` no descubre el namespace al arrancar.
- RF-6. `db` guarda sus datos en un volumen persistente de 1Gi, `ReadWriteOnce`, llamado `brewtrack-pgdata`. Nunca corren dos instancias de `db` a la vez sobre ese volumen.
- RF-7. Quitar la aplicación no borra los datos. Borrar el volumen es un paso aparte y documentado.
- RF-8. `db` y `api` solo se alcanzan dentro del clúster. Desde el host solo se alcanza `web`, con `kubectl port-forward`. Nada usa `hostPort`.
- RF-9. Antes de probar en el clúster, QA comprueba que el namespace `brewtrack` no existe. Si existe, es de la persona: QA no prueba en el clúster, no lo toca y se lo informa.

Salud y arranque
- RF-10. `db` se declara lista solo cuando `pg_isready` responde bien. `api` se declara lista solo cuando `/api/v1/health` responde 200. `web` se declara lista cuando sirve `/`.
- RF-11. `api` puede reiniciarse mientras `db` arranca, pero las tres piezas quedan listas sin intervención manual.

Configuración y secretos
- RF-12. `POSTGRES_PASSWORD` y `JWT_SECRET` entran por un Secret de Kubernetes llamado `brewtrack-secrets`, en el namespace `brewtrack`. La persona lo crea desde `.env` con `kubectl`. Ningún archivo versionado contiene el Secret ni sus valores.
- RF-13. La `DATABASE_URL` de `api` en el clúster apunta al Service `db` y se arma con la contraseña del Secret, igual que en `compose.yaml`. No se copia de `.env`.
- RF-14. `TIMEZONE` y `SEED_DEMO_LOTS` toman los mismos valores por defecto que en `compose.yaml`.
- RF-15. `manifest.yaml` no existe en la raíz ni se versiona.

Documentación
- RF-16. El repositorio documenta, en español, los comandos que corre la persona, en este orden (los nombres exactos los fija el developer). Usa `-n brewtrack` donde haga falta.
  1. Construir las imágenes con Podman.
  2. Cargarlas en Minikube con `minikube image load`.
  3. Crear el namespace `brewtrack` aplicando su manifiesto.
  4. Crear el Secret en `brewtrack` desde `.env` con `kubectl create secret`, sin mostrar valores en pantalla.
  5. Aplicar los manifiestos con `kubectl apply`.
  6. Esperar a que estén listos con `kubectl rollout status`.
  7. Crear el primer admin con `kubectl exec` sobre `api` y `python -m app.cli create-admin`.
  8. Abrir la web con `kubectl port-forward` hacia el Service `web` en el puerto 8080 del host.
  9. Actualizar una imagen: nueva etiqueta, `minikube image load` y nuevo `kubectl apply`.
  10. Quitar la aplicación, y por separado, borrar los datos.
- RF-17. `AGENTS.md` suma en "Comandos" una línea que apunte a esa documentación.

Restricción de trabajo
- RF-18. Developer y QA no dejan recursos de BrewTrack en el clúster. El developer solo usa `--dry-run`. QA, si RF-9 lo permite, aplica los manifiestos, prueba y al terminar borra el namespace `brewtrack` completo. Ninguno corre `minikube image load` ni crea nada en `default`. Si una prueba necesita imágenes nuevas en Minikube, se lo piden a la persona.

## Criterios de aceptación

Compose (stack levantado con `podman compose up --build -d`):
- CA-1. Dado el stack sano, cuando se pide `GET http://localhost:8080/api/v1/health`, entonces responde 200.
- CA-2. Dado CA-1, cuando se ejecuta `podman compose restart api` y `api` vuelve a estar sano, entonces `/api/v1/health` responde 200 a través de `web` sin reiniciar `web` (CA-1 de la spec 003).
- CA-3. Dado el stack, cuando se inspecciona el contenedor `web`, entonces no tiene definida la variable de RF-1 y el proxy usa `api`.

Manifiestos, sin crear nada:
- CA-4. Dado Minikube en marcha y sin namespace `brewtrack`, cuando se corre `kubectl apply --dry-run=client` con los manifiestos, entonces termina con código 0 y cada objeto sale como `created (dry run)`. Ninguno sale como `configured` ni `unchanged`.
- CA-5. Dados los manifiestos versionados, cuando se buscan valores para `POSTGRES_PASSWORD`, `JWT_SECRET` o una `DATABASE_URL` con contraseña literal, entonces no aparece ninguno. No hay ningún objeto `Secret` en los archivos versionados.
- CA-6. Dado el repositorio, entonces `manifest.yaml` no existe en la raíz y `git ls-files manifest.yaml` sale vacío.
- CA-7. Dados los manifiestos, entonces hay un objeto `Namespace` `brewtrack`, todos los demás objetos fijan `namespace: brewtrack`, el contenedor `web` define la variable de RF-1 con `api.brewtrack.svc.cluster.local`, ningún contenedor usa `hostPort` y los Services `db` y `api` no son `NodePort` ni `LoadBalancer`.

En clúster (QA, solo si `kubectl get namespace brewtrack` responde `NotFound`; con las imágenes ya cargadas por la persona y un Secret de prueba con valores inventados):
- CA-8. Dado el namespace `brewtrack` creado por QA con el Secret de prueba, cuando se aplican los manifiestos, entonces `kubectl rollout status -n brewtrack` de `db`, `api` y `web` termina bien en 180 s o menos, sin intervención manual.
- CA-9. Dado CA-8, cuando se listan los eventos de los Pods, entonces ninguno muestra descarga de imagen (`Pulling`) de `brewtrack-api` ni `brewtrack-web`.
- CA-10. Dado CA-8 y un `kubectl port-forward` del Service `web` al puerto 8080 del host, cuando se pide `GET http://localhost:8080/api/v1/health`, entonces responde 200.
- CA-11. Dado CA-10 y un cliente sin token, cuando pide `GET http://localhost:8080/api/v1/green-lots`, entonces recibe 401 con el cuerpo `{"error": {"code", "message"}}`.
- CA-12. Dado CA-10, cuando se crea un admin con `kubectl exec` y `create-admin`, inicia sesión y pide `GET http://localhost:8080/api/v1/green-lots?limit=5&offset=0`, entonces recibe 200 con `limit` 5 y `offset` 0 en el cuerpo.
- CA-13. Dado CA-10, cuando se pide `http://localhost:8080/lotes`, entonces responde 200 con `index.html`.
- CA-14. Dado CA-12, cuando se borra el Pod de `api` y el nuevo queda listo, entonces `/api/v1/health` responde 200 a través de `web` sin reiniciar `web`.
- CA-15. Dado CA-12, cuando se borra el Pod de `db` y el nuevo queda listo, entonces el admin creado sigue pudiendo iniciar sesión.
- CA-16. Dado CA-8, cuando se ejecutan los pasos de "quitar la aplicación" de RF-16, entonces el volumen `brewtrack-pgdata` sigue existiendo. Solo el paso de borrar datos lo elimina.

Limpieza y documentación:
- CA-17. Dado que QA probó en el clúster, cuando termina, entonces `kubectl get all,pvc,secret -n default` da la misma salida que antes de empezar y `kubectl get namespace brewtrack` responde `NotFound`.
- CA-18. Dada la documentación de RF-16, cuando se revisa, entonces trae los diez pasos en orden, con comandos que se pueden copiar, y ningún paso muestra ni pide escribir el valor de un secreto.
- CA-19. Dado el repositorio, entonces `cd api && pytest`, `cd web && flutter test` y `cd web && flutter analyze` pasan igual que antes.

## Chequeo de constitución

- **Alcance:** aplica. La constitución suma Minikube como destino adicional, en el namespace `brewtrack`, y deja compose como principal (CA-1 a CA-3). No suma funciones ni toca curvas, empaque, venta, recetas, cata ni multi-empresa.
- **Stock calculado:** no aplica. No cambia ningún cálculo.
- **Permisos en la API:** aplica. La API sigue imponiendo los permisos; nginx solo reenvía. CA-11 lo verifica.
- **Formato de error:** aplica. Los errores de la API llegan sin cambios a través de `web` en el clúster (CA-11). No hay endpoints nuevos.
- **Migraciones:** aplica en parte. No cambia el esquema. `api` sigue corriendo `alembic upgrade head` al arrancar, también en el clúster.
- **Secretos:** aplica. Los secretos entran por variable de entorno desde un Secret que la persona crea desde `.env`, como pide la constitución. Nadie escribe secretos en archivos versionados ni lee `.env` (RF-12, RF-13, RF-15, CA-5, CA-6).

## Fuera de alcance

- Dejar recursos de BrewTrack en el Minikube de la persona (RF-18).
- Desplegar en otro namespace que no sea `brewtrack`, o descubrir el namespace al arrancar.
- Ingress, TLS, nombres DNS para el host, registro de imágenes, Helm o Kustomize.
- Más de una réplica de `api` o `web`, autoescalado y alta disponibilidad de `db`.
- Backups automáticos en el clúster. Sigue valiendo el `pg_dump` manual (vía `kubectl exec`).
- Despliegues en clústeres que no sean Minikube local.
- CI/CD para el clúster (la constitución lo deja fuera).
- Cambiar el 502 de nginx mientras `api` arranca.

## Preguntas abiertas

Ninguna.

## Historial

| Fecha | Versión | Cambio |
|---|---|---|
| 2026-10-12 | 1.0 | Versión inicial a pedido de la persona usuaria. Registra como antecedente el cambio de nombre de los Containerfiles y las etiquetas fijas de imagen en `compose.yaml`, hechos fuera de spec. |
| 2026-10-12 | 1.1 | Respuestas de la persona. (1) La constitución y `AGENTS.md` suman Minikube como destino adicional: se ajusta el chequeo de alcance y se cierra la pregunta. (2) Namespace propio y fijo `brewtrack`: RF-5 pasa a objeto `Namespace` en los manifiestos y host fijo `api.brewtrack.svc.cluster.local` en `web`; RF-9 pasa a comprobar que `brewtrack` no exista antes de que QA pruebe; RF-12 fija el Secret en `brewtrack`; RF-16 suma el paso de crear el namespace (diez pasos) y usa `-n brewtrack`; RF-18 deja que solo QA cree y borre `brewtrack`; CA-7, CA-8, CA-17 y CA-18 se ajustan. CA-4 pasa a `--dry-run=client`, porque con `--dry-run=server` el namespace no llega a crearse y los objetos que lo fijan fallan. (3) La persona borró `manifest.yaml`: RF-15 y CA-6 exigen que no exista ni se versione. Recortes: se quita la etiqueta obligatoria `app.kubernetes.io/part-of=brewtrack` y la revisión de nombres en `default`, porque el namespace propio ya separa BrewTrack de los recursos ajenos. Estado: borrador listo para aprobar. |
| 2026-10-12 | 1.1 | Aprobada por la persona usuaria. |
| 2026-10-12 | 1.2 | Spec aceptada según el informe de QA (aprobado, CA-1 a CA-19 cumplen). CA-10: QA usó el puerto 18080 porque compose ocupaba el 8080; el proxy y la respuesta son los mismos, así que se acepta. CA-19 lo corrió el developer y QA no lo repitió; se acepta. Defecto 2: el README ya usa `kubectl exec -it`; el fallo vino de correr sin terminal; no requiere cambio. Defecto 1: tras borrar el Pod de `db`, el primer login falla una vez porque `api` guarda conexiones viejas. No incumple CA-15. Queda pendiente para una spec aparte: que `api` descarte conexiones muertas antes de usarlas. |
