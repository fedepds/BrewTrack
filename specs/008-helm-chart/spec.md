# 008 — Helm Chart para desplegar BrewTrack en Kubernetes

Estado: aprobada
Fecha: 2026-11-21

## Problema

Hoy BrewTrack se despliega en Kubernetes con manifiestos fijos en `k8s/`: `brewtrack.yaml` (`db` y `api`) y `web-bluegreen.yaml` (`web`). Para cambiar una imagen, el número de réplicas, los recursos o el puerto, hay que editar el YAML a mano. No hay forma de tener un despliegue de desarrollo y otro de producción con valores distintos sin copiar los archivos. Los valores que no son secretos (zona horaria, datos de ejemplo, dirección de la API para nginx) están escritos dentro de cada Deployment. No hay Ingress: la única entrada es un `port-forward`. Tampoco hay una forma de instalar, actualizar o borrar todo de una vez.

## Solución

Una Helm Chart en `helm-chart/`, en la raíz del repo, que despliega `db`, `api` y `web` con un solo comando:

```
helm install brewtrack ./helm-chart
```

La chart trae plantillas para Deployment, StatefulSet, Service, ConfigMap e Ingress, un `values.yaml` con los valores por defecto y dos archivos por entorno: `values-dev.yaml` (minikube, una réplica, datos de ejemplo, sin Ingress) y `values-prod.yaml` (más recursos, sin datos de ejemplo, con Ingress). Basta ese comando, sin pasos previos: la chart genera las claves al instalar, así que los secretos no entran en ningún archivo versionado ni hay que crearlos a mano. Tras instalar, `helm test` comprueba que la web responde y que llega a la API.

## Historias de usuario

1. Como operador, quiero instalar BrewTrack con `helm install <nombre> ./helm-chart`, para no aplicar varios YAML en orden.
2. Como operador, quiero cambiar la imagen y la etiqueta de `db`, `api` y `web` desde `values.yaml`, para desplegar otra versión sin editar plantillas.
3. Como operador, quiero fijar el número de réplicas de `web` desde los valores, para dar más capacidad a la interfaz.
4. Como operador, quiero fijar requests y limits de CPU y memoria por servicio, para que el clúster reparta bien los recursos.
5. Como operador, quiero cambiar el puerto de cada Service desde los valores, para adaptarme a la red del clúster.
6. Como operador, quiero elegir el tipo de Service de `web` (`ClusterIP` o `NodePort`), para entrar sin Ingress en minikube.
7. Como operador, quiero activar o desactivar el Ingress con un valor, para usarlo solo donde el clúster tenga un controlador.
8. Como operador, quiero fijar el host y la clase del Ingress, para publicar la web con el nombre del taller.
9. Como operador, quiero un `values-dev.yaml` que funcione en minikube con las imágenes cargadas a mano, para probar en mi máquina.
10. Como operador, quiero un `values-prod.yaml` con más recursos y sin lotes de ejemplo, para no mezclar datos falsos con los reales.
11. Como operador, quiero instalar con `helm install brewtrack ./helm-chart -f helm-chart/values-prod.yaml`, para elegir el entorno con un flag.
12. Como operador, quiero que los valores no secretos de la API (zona horaria, lotes de ejemplo) vivan en un ConfigMap, para verlos y cambiarlos en un solo sitio.
13. Como operador, quiero que la dirección de la API que usa nginx salga del ConfigMap y del nombre del release, para que la web encuentre a la API en cualquier namespace.
14. Como operador, quiero que `helm install <nombre> ./helm-chart` genere `POSTGRES_PASSWORD` y `JWT_SECRET` al azar, para que los pods arranquen sin pasos previos y ninguna clave quede en Git.
15. Como operador, quiero que `helm upgrade` conserve las claves generadas, para que la base siga aceptando su contraseña y nadie pierda la sesión.
16. Como operador, quiero poder nombrar un Secret propio desde los valores, para usar claves que gestiono yo en producción. Si ese Secret trae `SEED_ADMIN_EMAIL` y `SEED_ADMIN_PASSWORD`, la API crea el primer admin al arrancar, como en compose.
17. Como operador, quiero que la base de datos guarde sus datos en un volumen persistente de tamaño configurable, para no perder lotes ni tuestes al reiniciar.
18. Como operador, quiero que `helm uninstall` no borre el volumen de la base, para no perder datos por un error.
19. Como operador, quiero que todos los pods corran sin root y con raíz de solo lectura, como hoy en `k8s/`, para no perder el endurecimiento de la spec 004.
20. Como operador, quiero readiness y liveness probes en los tres servicios, para que Kubernetes no mande tráfico a un pod que no está listo y reinicie el que se colgó.
21. Como operador, quiero que la API tenga una sola réplica fija mientras corra las migraciones al arrancar, para no correr `alembic upgrade head` dos veces a la vez.
22. Como operador, quiero que `helm upgrade` reinicie la API cuando cambia el ConfigMap, para que tome los valores nuevos.
23. Como operador, quiero ejecutar `helm test <nombre>` y ver si la web y la API responden, para saber que el despliegue funciona sin abrir el navegador.
24. Como operador, quiero que `helm install` muestre al final las instrucciones para abrir la web y crear el primer admin, para no buscar en la documentación.
25. Como operador, quiero que `helm lint` pase sin errores, para detectar fallos antes de instalar.
26. Como operador, quiero instalar dos releases en namespaces distintos sin que choquen sus nombres, para tener dev y prod en el mismo clúster.
27. Como operador, quiero un README de la chart con los valores, los comandos de instalación por entorno y la verificación, para que otro lo pueda repetir.
28. Como `roaster`, quiero entrar a BrewTrack desplegado con Helm y usarlo igual que con compose, para no notar el cambio.

## Decisiones de implementación

- **Ubicación:** la chart vive en `helm-chart/` en la raíz. El nombre de la chart es `brewtrack`. `appVersion` sigue la etiqueta de la imagen de la API.
- **Una chart, tres componentes:** `db`, `api` y `web` van en la misma chart, sin subcharts ni dependencias externas (ni la chart de Bitnami para Postgres). `db` usa la imagen propia `brewtrack-db`, como hoy.
- **Objetos por componente:**
  - `db`: StatefulSet con `volumeClaimTemplates` y Service. Es el equivalente de Deployment para una base de datos; Helm no borra el PVC al desinstalar.
  - `api`: Deployment, Service y ConfigMap.
  - `web`: Deployment, Service e Ingress opcional.
- **Nombres:** todos los objetos llevan el prefijo del release (`<release>-api`, `<release>-db`, `<release>-web`) y las etiquetas estándar `app.kubernetes.io/*`. La `DATABASE_URL` y el `API_UPSTREAM` de nginx se arman con esos nombres, con el nombre completo del Service (`<release>-api.<namespace>.svc.cluster.local`), porque el resolver de nginx no completa nombres cortos.
- **Namespace:** la chart no crea namespace. Se usa `--namespace` y `--create-namespace` de Helm.
- **ConfigMap de la API:** guarda `TIMEZONE`, `SEED_DEMO_LOTS` y el `API_UPSTREAM` de nginx. Los pods lo leen con `envFrom`. El Deployment lleva una anotación con el hash del ConfigMap para reiniciar al cambiar.
- **Secretos:** la letra pide que `helm install <nombre> ./helm-chart` deje los pods en marcha, sin pasos previos. Por eso la chart trae una plantilla de Secret (`<release>-secrets`) que, con `existingSecret` vacío (el valor por defecto), genera al instalar `POSTGRES_PASSWORD` (32 caracteres al azar) y `JWT_SECRET` (64 caracteres al azar, por encima del mínimo de 32 de la spec 004).
  - En `helm upgrade`, la plantilla lee el Secret que ya existe (`lookup`) y reusa sus valores. Si los cambiara, Postgres rechazaría la contraseña nueva (solo la lee al crear la base) y todos los usuarios perderían la sesión.
  - El Secret lleva la anotación `helm.sh/resource-policy: keep`: `helm uninstall` no lo borra, igual que el volumen de la base, para que una reinstalación siga abriendo los datos viejos.
  - Ningún archivo de valores trae claves ni campos para escribirlas. Los pods las leen como variables de entorno con `secretKeyRef`. Así se cumple la constitución: todo secreto entra por variable de entorno y nada se versiona.
  - Si `existingSecret` tiene un nombre, la chart no crea el Secret y usa ese, con las mismas claves y, si están, `SEED_ADMIN_EMAIL` y `SEED_ADMIN_PASSWORD`. Es la opción para producción.
  - Sin Secret propio no hay admin al arrancar: NOTES.txt da el comando de la CLI `create-admin`.
- **Forma de `values.yaml`:** un bloque por componente con la misma forma:

  ```yaml
  api:
    image: { repository: localhost/brewtrack-api, tag: "0.1.0", pullPolicy: IfNotPresent }
    replicas: 1
    service: { type: ClusterIP, port: 8000 }
    resources: { requests: {...}, limits: {...} }
    config: { timezone: America/Argentina/Buenos_Aires, seedDemoLots: "true" }
  web:   # igual, con service.port 8080
  db:    # igual, con persistence: { size: 1Gi, storageClass: "" }
  ingress: { enabled: false, className: "", host: brewtrack.local, annotations: {} }
  existingSecret: ""   # vacío: la chart genera el Secret
  ```

- **Réplicas de la API:** la plantilla fija 1 réplica para `api` aunque los valores digan otra cosa, y lo comenta, hasta que las migraciones salgan a un Job (mismo límite que marca hoy `k8s/brewtrack.yaml`). `db` también queda en 1. Solo `web` escala.
- **`values.yaml` por defecto:** funciona en minikube tal cual (imágenes `localhost/*` con `IfNotPresent`, Ingress apagado), para que el comando de la letra sirva sin `-f`.
- **Entornos:**
  - `values-dev.yaml`: imágenes `localhost/*` con `IfNotPresent`, 1 réplica de `web`, recursos bajos, `seedDemoLots: "true"`, Service de `web` tipo `NodePort`, Ingress apagado.
  - `values-prod.yaml`: 2 réplicas de `web`, recursos más altos, `seedDemoLots: "false"`, volumen de 10 Gi, Ingress encendido con host y clase `nginx`. TLS queda fuera (ver abajo).
- **Seguridad de los pods:** se copian tal cual los `securityContext` de `k8s/` (UID 70 para `db`, 1000 para `api`, 101 para `web`, `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`) y los `emptyDir` que cada imagen necesita para escribir.
- **Probes:** `db` con `pg_isready`; `api` con `GET /api/v1/health`; `web` con `GET /` en el puerto 8080. Readiness y liveness en los tres.
- **Verificación:** un pod de `helm test` (anotación `helm.sh/hook: test`) hace `GET` a `http://<release>-web:<puerto>/api/v1/health` y falla si no recibe 200. Así prueba a la vez que `web` sirve, que el proxy llega a `api` y que `api` llega a `db`.
- **NOTES.txt:** al instalar, imprime cómo abrir la web (`port-forward`, NodePort o host del Ingress, según los valores), cómo leer una clave generada (`kubectl get secret ... -o jsonpath`) y cómo crear el primer admin con la CLI.
- **`k8s/` y Jenkins:** los manifiestos de `k8s/` quedan como están. Prometheus y Grafana no entran en la chart. Cambiar el stage `Deploy minikube` del `Jenkinsfile` para usar `helm upgrade --install` es una tarea aparte, fuera de esta spec.

## Decisiones de pruebas

- Una buena prueba mira lo que ve el operador: lo que renderiza la chart y lo que responde el clúster. No mira cómo están escritas las plantillas por dentro.
- **Seam principal: `helm test`** sobre un release instalado en minikube. Es el punto más alto: un solo GET a `/api/v1/health` a través de `web` prueba los tres componentes y la red entre ellos.
- **Seam secundario, sin clúster: `helm lint` y `helm template`** con cada archivo de valores (`values.yaml`, `values-dev.yaml`, `values-prod.yaml`). QA comprueba en la salida renderizada:
  - que existen Deployment (`api`, `web`), StatefulSet (`db`), los tres Services y el ConfigMap;
  - que el Ingress aparece solo con `ingress.enabled=true`;
  - que las réplicas, imágenes, puertos y recursos cambian según el archivo de valores;
  - que `api` sigue con 1 réplica aunque se pida más;
  - que el Secret `<release>-secrets` aparece solo con `existingSecret` vacío, y que con un nombre los pods leen ese Secret;
  - que ningún archivo `values*.yaml` trae claves ni contraseñas.
- **Prueba en vivo (criterio de aceptación):** en minikube, con las imágenes cargadas y sin crear nada antes:
  1. `helm install brewtrack ./helm-chart -n brewtrack-helm --create-namespace` termina sin error. Se repite con `-f helm-chart/values-dev.yaml` en otro namespace.
  2. `kubectl -n brewtrack-helm get pods` muestra todos los pods `Running` y `Ready` en menos de 3 minutos.
  3. `helm test brewtrack -n brewtrack-helm` pasa.
  4. `kubectl port-forward svc/brewtrack-web 8081:8080` y http://localhost:8081 carga la pantalla de login; el login con el admin funciona.
  5. `helm upgrade brewtrack ./helm-chart -n brewtrack-helm` no cambia los valores del Secret, la API sigue sana y la sesión abierta sigue valiendo.
  6. `helm uninstall` deja el PVC de la base y el Secret; un `helm install` nuevo con el mismo nombre vuelve a abrir los datos.
- QA anota en `qa-report.md` la salida de los pasos 2 y 3.
- **Precedente en el repo:** no hay tests de infraestructura. Lo más cercano son los healthchecks de `compose.yaml`, las readiness probes de `k8s/brewtrack.yaml` y el stage `Deploy minikube` del `Jenkinsfile`, que ya espera con `rollout status`.
- `pytest` y `flutter test` siguen pasando; esta spec no toca código de la app.

## Fuera de alcance

- Prometheus, Grafana y el blue/green de `web` (siguen en `k8s/`).
- Cambiar el `Jenkinsfile` para desplegar con Helm.
- TLS y cert-manager (la constitución deja TLS fuera de v1).
- Publicar la chart en un repositorio de charts o subir imágenes a un registro.
- Job de migraciones y escalar la API a más de una réplica.
- HorizontalPodAutoscaler, NetworkPolicy y PodDisruptionBudget.
- Backups automáticos de la base.
- Rotar las claves generadas.

## Notas

- Cumple la constitución: no cambia el esquema ni la API, los secretos entran por variable de entorno y no se versionan, y los permisos siguen en la API.
- minikube necesita el addon `ingress` solo para probar `values-prod.yaml` con Ingress; dev no lo usa.
- Si Ingress se enciende en minikube, el host (`brewtrack.local`) hay que mapearlo a `minikube ip` en `/etc/hosts`; el README de la chart lo explica.
