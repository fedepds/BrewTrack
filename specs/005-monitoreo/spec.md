# 005 — Monitoreo de la API con Prometheus y Grafana

Estado: aceptada
Fecha: 2026-10-13

## Contexto y objetivo

Hoy nadie ve qué pasa en la API mientras corre. Si se cae, se pone lenta o alguien prueba contraseñas, el taller se entera tarde o nunca.

La constitución ya suma el monitoreo (commit c26c758): servicios `prometheus` y `grafana`, `GET /metrics` fuera de `/api/v1` y la variable `GRAFANA_ADMIN_PASSWORD`. Grafana publica puerto solo en `127.0.0.1` y no admite acceso anónimo. nginx no publica `/metrics`.

Objetivo: que el admin del taller, que también opera el despliegue, vea en Grafana:
1. el tráfico y la salud HTTP de la API;
2. señales de seguridad: logins fallidos y accesos denegados.

Las alertas solo se ven en Grafana. No hay avisos por correo ni chat.

Decisiones de la persona usuaria, ya acordadas:
- La API usa la dependencia `prometheus-fastapi-instrumentator` para medir.
- La configuración vive en `monitoring/`, con un solo juego de archivos para compose y Minikube.
- Grafana publica en `127.0.0.1:3001`, porque la persona ya usa otro Grafana en el 3000.

## Historias de usuario

- HU-1. Como `admin`, quiero ver en un panel los pedidos por minuto, el porcentaje de errores 5xx y la latencia p95, para saber si la API anda bien.
- HU-2. Como `admin`, quiero que Grafana me muestre una alerta cuando la API se cae, falla o se pone lenta, para actuar sin revisar el panel a cada rato.
- HU-3. Como `admin`, quiero ver una alerta cuando hay muchos logins fallidos o accesos denegados, para detectar a quien prueba contraseñas o fuerza permisos.
- HU-4. Como `admin`, quiero que paneles y alertas aparezcan solos al levantar el stack, en compose y en Minikube, sin pasos a mano en Grafana.
- HU-5. Como `admin`, quiero cambiar un umbral editando un archivo, sin tocar código.

## Requisitos funcionales

Métricas en la API
- RF-1. La API expone `GET /metrics` en la raíz, en el formato de texto de Prometheus. No está bajo `/api/v1` ni aparece en `/api/v1/openapi.json`.
- RF-2. La API publica dos métricas HTTP: un contador de pedidos y un histograma de latencia.
- RF-3. Las dos métricas llevan tres etiquetas: ruta, método y código de estado.
  - La ruta es la plantilla, por ejemplo `/api/v1/green-lots/{lot_id}`. Nunca lleva un UUID ni otro valor del pedido.
  - El código de estado es exacto (`401`, `403`, `500`), sin agrupar en `4xx` o `5xx`.
- RF-4. Los pedidos a rutas que no existen se cuentan bajo un solo valor de ruta. Una URL inventada no crea una serie nueva.
- RF-5. Los pedidos a `/metrics` y a `/api/v1/health` no se cuentan en ninguna de las dos métricas.
- RF-6. nginx sigue haciendo proxy solo de `/api/`. `http://localhost:8081/metrics` no devuelve métricas.

Configuración compartida (`monitoring/`)
- RF-7. `monitoring/prometheus.yml` lee `api:8000/metrics` cada 15 s.
- RF-8. `monitoring/grafana/provisioning/` trae todo lo que Grafana carga al arrancar:
  - la fuente de datos Prometheus en `http://prometheus:9090`;
  - el panel "BrewTrack API";
  - las reglas de alerta, gestionadas por Grafana.
- RF-9. El panel "BrewTrack API" muestra cinco gráficos: pedidos por minuto, porcentaje de respuestas 5xx, latencia p95, logins fallidos (401 en `POST /api/v1/auth/login`) y respuestas 401/403.
- RF-10. Grafana carga seis reglas de alerta, con estos nombres y reglas:

  | Alerta | Regla |
  |---|---|
  | Tráfico alto | más de 300 pedidos/min sostenidos durante 5 min |
  | Errores del servidor | más del 5 % de respuestas 5xx durante 5 min |
  | API lenta | latencia p95 por encima de 1 s durante 5 min |
  | API caída | Prometheus no logra leer `/metrics` durante 1 min |
  | Fuerza bruta | más de 10 respuestas 401 en `POST /api/v1/auth/login` en 5 min |
  | Accesos denegados | más de 30 respuestas 401/403 en 5 min, sin contar el login |

- RF-11. "Fuerza bruta" y "Accesos denegados" cuentan cada respuesta, también la primera 401 o 403 que recibe una ruta desde que arrancó la API.
- RF-12. Sin tráfico, ninguna alerta pasa a estado de disparo, salvo "API caída" si la API no responde.
- RF-13. Los umbrales y las duraciones de RF-10 se cambian editando el archivo de reglas en `monitoring/`. No hace falta tocar código de la API ni reconstruir su imagen.
- RF-14. Compose y Minikube usan los mismos archivos de `monitoring/`. Ninguno de los dos copia la configuración en otro archivo.

Compose
- RF-15. `compose.yaml` suma los servicios `prometheus` y `grafana`, con versión de imagen fija (nunca `latest` ni sin etiqueta). Cada uno tiene su volumen.
- RF-16. Grafana publica en `127.0.0.1:3001`. Prometheus no publica puerto al host.
- RF-17. Grafana toma la contraseña de admin de `GRAFANA_ADMIN_PASSWORD`, que viene de `.env`. Si falta, compose no levanta `grafana` con una contraseña por defecto: falla con un mensaje que nombra la variable.
- RF-18. Grafana no admite acceso anónimo.
- RF-19. `.env.example` documenta `GRAFANA_ADMIN_PASSWORD` sin un valor real.
- RF-20. La imagen `api` cambia de etiqueta por la dependencia nueva, en `compose.yaml` y en los manifiestos de Minikube a la vez. El developer propone el valor.

Minikube (namespace `brewtrack`)
- RF-21. Un manifiesto nuevo, `k8s/monitoring.yaml`, trae un Deployment y un Service para `prometheus` y otro par para `grafana`, con las mismas imágenes que compose. Todos los objetos fijan `namespace: brewtrack`.
- RF-22. La configuración entra al clúster con ConfigMaps que la persona crea con `kubectl create configmap --from-file` desde `monitoring/`. `k8s/monitoring.yaml` no contiene la configuración.
- RF-23. `GRAFANA_ADMIN_PASSWORD` se suma al Secret `brewtrack-secrets`, con el mismo `grep` sobre `.env` que ya usa `k8s/README.md`. Ningún archivo versionado contiene su valor.
- RF-24. Los Services `prometheus` y `grafana` no son `NodePort` ni `LoadBalancer`, y nada usa `hostPort`. Se llega a Grafana con `kubectl port-forward -n brewtrack svc/grafana 3001:3000`.
- RF-24b. En Minikube, `prometheus` y `grafana` no usan volumen persistente: sus datos viven en un `emptyDir`. Al borrar el Pod se pierde el historial de métricas. El panel y las alertas vuelven desde las ConfigMaps, y la contraseña desde el Secret. Compose sigue con un volumen por servicio (RF-15).
- RF-25. Valen las reglas de trabajo de la spec 004 (RF-9 y RF-18): developer y QA no dejan recursos de BrewTrack en el clúster; QA solo prueba si el namespace `brewtrack` no existe y lo borra al terminar. Si hacen falta imágenes nuevas en Minikube, se las piden a la persona.

Documentación
- RF-26. `k8s/README.md` suma, en español y con comandos que se pueden copiar: crear las ConfigMaps, sumar `GRAFANA_ADMIN_PASSWORD` al Secret, aplicar `k8s/monitoring.yaml`, esperar con `kubectl rollout status`, abrir Grafana con `port-forward` y actualizar las ConfigMaps tras cambiar un umbral.
- RF-27. `AGENTS.md` suma en "Comandos" una línea para abrir Grafana en compose (`http://127.0.0.1:3001`).
- RF-28. La documentación avisa que Grafana guarda la contraseña de admin en su volumen la primera vez que arranca. Cambiar `GRAFANA_ADMIN_PASSWORD` después no la cambia; explica cómo hacerlo.

## Criterios de aceptación

Pruebas de la API (pytest):
- CA-1. Dada la API, cuando se pide `GET /metrics`, entonces responde 200 con métricas en formato de texto de Prometheus.
- CA-2. Dado un `POST /api/v1/auth/login` con contraseña incorrecta, cuando se pide `GET /metrics`, entonces el contador de pedidos tiene una serie con ruta `/api/v1/auth/login`, método `POST` y `status="401"`, con valor 1 o más.
- CA-3. Dados varios `GET /api/v1/health`, cuando se pide `GET /metrics`, entonces ninguna serie de las dos métricas tiene la ruta `/api/v1/health` ni `/metrics`.
- CA-4. Dado un `GET /api/v1/green-lots/{id}` con un UUID real, cuando se pide `GET /metrics`, entonces aparece la ruta `/api/v1/green-lots/{lot_id}` y el UUID no aparece en ninguna parte de la respuesta.
- CA-5. Dado un `GET` a dos URLs inventadas distintas, cuando se pide `GET /metrics`, entonces ninguna de las dos URLs aparece en la respuesta.
- CA-6. Dada la API, cuando se pide `GET /api/v1/openapi.json`, entonces no lista `/metrics`.

Compose (stack levantado con `podman compose up --build -d`):
- CA-7. Dado `monitoring/prometheus.yml`, cuando se corre `promtool check config` sobre él, entonces termina con código 0.
- CA-8. Dado el stack sano, cuando se pide `http://localhost:8081/metrics`, entonces la respuesta no contiene ninguna métrica de la API (ni el nombre del contador ni el del histograma).
- CA-9. Dado el stack, cuando se inspeccionan los puertos, entonces `grafana` publica solo `127.0.0.1:3001` y `prometheus` no publica ninguno.
- CA-10. Dado el stack, cuando un cliente sin credenciales pide `GET http://127.0.0.1:3001/api/search`, entonces recibe 401. Cuando abre `http://127.0.0.1:3001/`, entonces llega a la pantalla de login.
- CA-11. Dado el stack recién levantado, sin pasos a mano, cuando el admin entra a Grafana, entonces ve la fuente de datos Prometheus, el panel "BrewTrack API" con los cinco gráficos de RF-9 y las seis alertas de RF-10 con esos nombres.
- CA-12. Dada la API recién arrancada y sin 401 previos, cuando se hacen 11 logins fallidos en menos de 1 min, entonces "Fuerza bruta" pasa a estado de disparo en Grafana en 3 min o menos desde el último login.
- CA-13. Dado CA-12, cuando pasan 10 min sin logins fallidos, entonces "Fuerza bruta" vuelve a normal.
- CA-14. Dado el stack sano, cuando se corre `podman compose stop api`, entonces "API caída" pasa a estado de disparo en 3 min o menos.
- CA-15. Dado el stack sano y sin tráfico durante 10 min, cuando se revisan las alertas, entonces ninguna está en estado de disparo.
- CA-16. Dado el archivo de reglas, cuando se cambia el umbral de "Fuerza bruta" de 10 a 3 y se reinicia solo `grafana`, entonces 4 logins fallidos la disparan. La imagen `api` no se reconstruye.
- CA-17. Dado un `.env` sin `GRAFANA_ADMIN_PASSWORD`, cuando se levanta el stack, entonces `grafana` no arranca y el error nombra la variable.
- CA-18. Dado `compose.yaml` y `k8s/monitoring.yaml`, entonces las imágenes de `prometheus` y `grafana` llevan la misma versión fija en ambos, distinta de `latest`.

Minikube, sin crear nada:
- CA-19. Dado Minikube en marcha y sin namespace `brewtrack`, cuando se corre `kubectl apply --dry-run=client` con `k8s/` completo, entonces termina con código 0 y cada objeto sale como `created (dry run)`.
- CA-20. Dado `k8s/monitoring.yaml`, entonces todos los objetos fijan `namespace: brewtrack`, ningún contenedor usa `hostPort`, ningún Service es `NodePort` ni `LoadBalancer` y no hay ConfigMap ni Secret con la configuración o la contraseña.
- CA-21. Dados los archivos versionados, cuando se busca un valor para `GRAFANA_ADMIN_PASSWORD`, entonces no aparece ninguno.

En clúster (QA, solo si `kubectl get namespace brewtrack` responde `NotFound`, con las imágenes ya cargadas por la persona y un Secret de prueba con valores inventados):
- CA-22. Dado el namespace creado por QA con el Secret y las ConfigMaps según `k8s/README.md`, cuando se aplican los manifiestos, entonces `kubectl rollout status -n brewtrack` de `db`, `api`, `web`, `prometheus` y `grafana` termina bien en 240 s o menos.
- CA-23. Dado CA-22 y el `port-forward` de RF-24 (o otro puerto libre si compose ocupa el 3001), cuando el admin entra a Grafana, entonces ve lo mismo que en CA-11.
- CA-24. Dado CA-23, cuando se hacen 11 logins fallidos a través de `web`, entonces "Fuerza bruta" pasa a estado de disparo en 3 min o menos.
- CA-25. Dado CA-23, cuando un cliente sin credenciales pide `GET /api/search` a Grafana, entonces recibe 401.
- CA-25b. Dado CA-23, cuando se borra el Pod de `grafana` y el nuevo queda listo, entonces el admin entra con la contraseña del Secret y ve lo mismo que en CA-11. No hay ningún PersistentVolumeClaim de `prometheus` ni de `grafana` en `brewtrack`.
- CA-26. Dado que QA probó en el clúster, cuando termina, entonces `kubectl get namespace brewtrack` responde `NotFound` y `kubectl get all,pvc,secret,configmap -n default` da la misma salida que antes de empezar.

Documentación y regresión:
- CA-27. Dado `k8s/README.md`, cuando se revisa, entonces trae los pasos de RF-26 en orden, y ningún paso muestra ni pide escribir el valor de un secreto.
- CA-28. Dados `AGENTS.md` y la documentación, entonces aparecen la línea de RF-27 y el aviso de RF-28.
- CA-29. Dado el repositorio, entonces `cd api && pytest`, `cd web && flutter test` y `cd web && flutter analyze` pasan, y la API sigue respondiendo como antes en `/api/v1` (`/api/v1/health` responde 200 a través de `web`).

## Chequeo de constitución

- **Alcance:** aplica. La constitución ya suma el monitoreo de la API con Prometheus y Grafana. La spec solo mide tráfico HTTP. No toca curvas, empaque, venta, recetas, cata ni multi-empresa, y deja fuera las métricas de negocio.
- **Stock calculado:** no aplica. No mide ni guarda stock.
- **Permisos en la API:** aplica. Ningún endpoint de `/api/v1` cambia sus permisos. `/metrics` no lleva login, pero la constitución lo deja fuera de `/api/v1` y nginx no lo publica (RF-6, CA-8). Solo lo alcanzan los contenedores de la red interna. Las métricas no llevan datos del negocio, IP ni usuario (RF-3, RF-4). Grafana exige login (CA-10, CA-25).
- **Formato de error:** aplica en parte. No hay endpoints nuevos en `/api/v1`. `/metrics` responde texto de Prometheus, no JSON, como pide su formato. Los errores de `/api/v1` no cambian.
- **Migraciones:** no aplica. No cambia el esquema.
- **Secretos:** aplica. `GRAFANA_ADMIN_PASSWORD` entra por variable de entorno desde `.env` en compose y desde el Secret `brewtrack-secrets` en Minikube. Nadie la escribe en un archivo versionado ni lee `.env` (RF-17, RF-19, RF-23, CA-21).

## Fuera de alcance

- Avisos por correo o chat. Se suman después con un contact point de Grafana.
- Métricas de negocio: tuestes, lotes y stock.
- Distinguir por IP o por usuario. Multiplica las series; para saber el origen se usan los logs.
- Limitar la cantidad de pedidos (rate limiting).
- Métricas de `db`, `web` o del host.
- Cambios en el frontend. No hay tests de widgets nuevos.
- Publicar Prometheus o Grafana fuera de `127.0.0.1`, TLS e Ingress.

## Preguntas abiertas

- PA-1 (cerrada). En Minikube, ¿Prometheus y Grafana guardan sus datos en un volumen persistente? Decisión de la persona: no; usan `emptyDir` (RF-24b, CA-25b).
- PA-2 (cerrada). Pruebas en Minikube: CA-19 y CA-22 a CA-26 (incluido CA-25b) no se probaron. Minikube está parado y el namespace `brewtrack` ya existe por la spec 004, así que RF-25 impide que QA pruebe. Opciones:
  1. La persona arranca Minikube, construye y carga `brewtrack-api:0.2.0`, y quita su namespace `brewtrack` para que QA pruebe y lo borre al terminar.
  2. La persona sigue `k8s/README.md` en su namespace y comprueba ella misma CA-22 a CA-25b.
  3. La persona da por buena la revisión por lectura (CA-20, CA-27) y anota la renuncia en el Historial.
  Decisión de la persona: el developer prueba en el namespace `brewtrack` de la persona, sin borrarlo. CA-26 no aplica.
- PA-3 (cerrada). Puerto de `web` en compose: pasó de 8080 a 8081 en `compose.yaml`, `AGENTS.md`, `README.md`, `k8s/README.md` y los agentes. Esta spec no lo pide, aunque RF-6 y CA-8 ya usan 8081. El cambio contradice la spec 004 aceptada: RF-16 paso 8 y CA-1, CA-10 a CA-13 fijan el 8080. Opciones:
  1. Lo acepta en esta rama. Entonces la spec 004 suma una línea en su Historial con el puerto nuevo.
  2. Lo separa en otro cambio. Entonces esta rama vuelve al 8080, y RF-6 y CA-8 de esta spec pasan a 8080 con su línea en el Historial.
  Decisión de la persona: opción 1.
- PA-4 (cerrada). Revisión humana de la redacción y de los comentarios del código. QA no la hace. Decisión de la persona: la hace sobre el commit local, antes de subir la rama.

## Historial

| Fecha | Versión | Cambio |
|---|---|---|
| 2026-10-13 | 1.0 | Versión inicial según el diseño acordado con la persona usuaria y la constitución del commit c26c758. El PO suma, sin cambiar el diseño: RF-4 (URLs inventadas no crean series), RF-11 (contar también la primera 401 de una ruta, para que 11 logins disparen "Fuerza bruta"), RF-12 (sin tráfico no hay alertas), RF-17 (sin contraseña, `grafana` no arranca), RF-20 (nueva etiqueta de `api`), RF-27 y RF-28 (documentación). Estado: borrador. |
| 2026-10-13 | 1.1 | Respuesta de la persona a PA-1: en Minikube, `prometheus` y `grafana` usan `emptyDir`, sin volumen persistente; compose sigue con un volumen por servicio. Se suman RF-24b y CA-25b y se cierra PA-1. Aprobada por la persona usuaria. |
| 2026-10-13 | 1.2 | Aceptada con condiciones abiertas, según el informe de QA de la segunda ronda (aprobado con observaciones). El fallo de RF-11 y CA-12 está arreglado: tras reiniciar `api`, las series 401 y 403 existen en 0, y 11 logins fallidos disparan "Fuerza bruta" en 65 s. Cumplen CA-1 a CA-18, CA-21 y CA-29. CA-20, CA-27 y CA-28 cumplen por lectura; se aceptan, porque piden revisar archivos. CA-13 se comprobó a los 10 min y no en el instante exacto; se acepta, porque el criterio pide la vuelta a normal a los 10 min. No se piden cambios al developer. Quedan para la persona: PA-2 (pruebas en Minikube, sin las cuales HU-4 y RF-21 a RF-24b no se cierran), PA-3 (puerto 8081 de `web`, fuera de esta spec) y PA-4 (revisión de redacción y comentarios). La spec pasa a "aceptada" cuando la persona cierre las tres. |
| 2026-10-14 | 1.3 | Respuestas de la persona. PA-2: el developer prueba en el namespace `brewtrack` de la persona y no lo borra, así que CA-26 no aplica. Con `brewtrack-api:0.2.0` cargada: CA-19 sale con código 0 (los objetos salen `unchanged` o `configured` porque el namespace ya existe); CA-22 tarda 67 s; CA-23 muestra la fuente, el panel con 5 gráficos y las 6 alertas; CA-24 dispara "Fuerza bruta" 70 s después del último login; CA-25 da 401; CA-25b cumple tras borrar el Pod y no hay PVC de `prometheus` ni `grafana`. La prueba encontró un `~` antes del comentario de la línea 1 de `k8s/brewtrack.yaml`: `kubectl apply` rechazaba el PVC y el dry-run de cliente no lo vio. Se corrigió. PA-3: se acepta el 8081 en esta rama; la spec 004 suma su línea. PA-4: la persona revisa el commit local. Spec aceptada. |
