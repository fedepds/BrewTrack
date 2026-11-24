# 010 — SlimToolkit: análisis de capas y una imagen `web` reducida

Estado: aprobada
Fecha: 2026-11-23

## Problema

El cliente pide imágenes más chicas. Hoy pesan 429 MB (`db`), 389 MB (`api`) y 165 MB (`web`), y nadie sabe qué capas ni qué archivos ocupan ese lugar. El pipeline construye, escanea y despliega las imágenes, pero no mide su tamaño ni su composición, así que no hay datos para decidir qué recortar. Tampoco hay forma de probar una imagen reducida sin arriesgar el deploy.

## Solución

El pipeline usa SlimToolkit en dos fases:

1. **Análisis (`slim xray`)** de `db`, `api` y `web` en cada ejecución. Muestra cada capa, su tamaño, la instrucción que la creó y los archivos que agrega o pisa. Los informes quedan en `reports/slimtoolkit/` y Jenkins los guarda como artefactos de cada build. Este paso solo informa y nunca corta el pipeline.
2. **Reducción (`slim build`) solo de `web`.** El pipeline crea una imagen `brewtrack-web:<tag>-slim`, la prueba, la escanea con Trivy y la publica en el registro local, junto a la normal. Todavía no se despliega: el deploy sigue usando la imagen normal. Un informe compara los tamaños de las dos.

Si falla la fase 2, el build queda `UNSTABLE` (amarillo) y el deploy sigue con la imagen normal.

Un script del repo hace el mismo trabajo en la máquina del desarrollador, contra imágenes locales, sin Jenkins.

## Historias de usuario

1. Como responsable del proyecto, quiero un informe de capas de cada imagen en cada build, para mostrarle al cliente qué ocupa lugar.
2. Como responsable del proyecto, quiero el tamaño total de cada imagen en el informe, para seguir su evolución entre builds.
3. Como desarrollador, quiero ver qué instrucción del `Containerfile` creó cada capa, para saber qué línea cambiar.
4. Como desarrollador, quiero ver qué archivos agrega, cambia o borra cada capa, para encontrar archivos duplicados entre capas (por ejemplo, los que deja `apk upgrade` o `apt-get upgrade`).
5. Como desarrollador, quiero ver las capas heredadas de la imagen base separadas de las nuestras, para distinguir lo que controlamos de lo que no.
6. Como desarrollador, quiero que los informes se llamen como la imagen y su etiqueta, para saber de qué commit es cada uno.
7. Como desarrollador, quiero que los informes estén en `reports/slimtoolkit/`, junto a los de Semgrep y Snyk, para buscarlos en un solo lugar.
8. Como desarrollador, quiero bajar los informes de cualquier build anterior desde Jenkins, para comparar dos builds.
9. Como desarrollador, quiero un informe que pueda leer una persona y otro que pueda leer una máquina (JSON), para revisarlos a mano y procesarlos después.
10. Como desarrollador, quiero que el análisis no corte el pipeline, para que una falla de SlimToolkit no frene un deploy.
11. Como desarrollador, quiero que el análisis corra junto a Trivy y Snyk, para no alargar el pipeline.
12. Como desarrollador, quiero que el pipeline use una versión fija de SlimToolkit, para que dos builds del mismo commit den el mismo resultado.
13. Como desarrollador, quiero una imagen `web` reducida en cada build, para medir cuánto se puede ahorrar.
14. Como desarrollador, quiero que la imagen reducida tenga la misma etiqueta que la normal más `-slim`, para emparejarlas.
15. Como desarrollador, quiero que la imagen reducida sirva `/`, `/index.html`, una ruta interna de la SPA y `main.dart.js`, para saber que no perdió archivos de la app.
16. Como desarrollador, quiero que la imagen reducida conserve la plantilla de nginx y los scripts de arranque, para que el proxy hacia `api` siga funcionando.
17. Como desarrollador, quiero que la imagen reducida corra sin root en el puerto 8080, igual que la normal, para no perder el endurecimiento de la spec 004.
18. Como desarrollador, quiero que la imagen reducida pase el mismo escaneo de Trivy que la normal, para no publicar una imagen menos segura.
19. Como desarrollador, quiero un informe que compare el tamaño de `web` normal y `web` reducida, para darle al cliente una cifra concreta.
20. Como desarrollador, quiero que el build quede `UNSTABLE` si falla la reducción o su prueba, para enterarme sin perder el deploy.
21. Como desarrollador, quiero que la imagen reducida quede en el registro local, para probarla a mano en minikube si quiero.
22. Como operador, quiero que el deploy siga usando la imagen normal, para que este cambio no ponga en riesgo lo que hoy funciona.
23. Como desarrollador, quiero correr el análisis y la reducción en mi máquina con un solo comando, para probar cambios en un `Containerfile` sin esperar a Jenkins.
24. Como desarrollador, quiero que el script local deje los informes en la misma carpeta y con los mismos nombres que en Jenkins, para no aprender dos formatos.
25. Como desarrollador, quiero que los informes que genera CI no entren en Git, para no ensuciar el historial con un archivo por build.

## Decisiones de implementación

- **Herramienta:** imagen oficial `dslim/slim`, con una versión fija. Corre como contenedor con acceso al socket de Docker, como la etapa de Trivy para imágenes.
- **Script único:** un script nuevo en `ci/` hace todo el trabajo de SlimToolkit. El `Jenkinsfile` solo lo llama, y el desarrollador lo corre igual en local. Recibe las referencias de las tres imágenes (repositorio y etiqueta) y escribe en `reports/slimtoolkit/`. Precedente: `ci/snyk-cli.sh`.
- **Dos modos del script:** análisis (`xray` de las tres imágenes) y reducción (`build` de `web` con su prueba). Así Jenkins puede marcar cada fase por separado.
- **Lugar en el pipeline:**
  - El análisis es una etapa más dentro de `Escaneo de imágenes`, en paralelo con Trivy y Snyk. Si falla, la etapa queda `UNSTABLE` y no corta nada.
  - La reducción de `web` va en una etapa propia después de `Build imágenes`. Construye, prueba con `docker run` y `curl`, y escanea con Trivy. Si algo falla, el build queda `UNSTABLE`.
  - `Publicar imágenes` sube la `-slim` solo si su etapa pasó.
  - `Deploy Helm` no cambia.
- **Informes, por imagen y build:**
  - un JSON de `xray`;
  - un resumen de texto con el tamaño total y, por capa, el tamaño y la instrucción que la creó;
  - para `web`, un resumen que compara el tamaño normal con el reducido.

  Los nombres llevan la imagen y su etiqueta (por ejemplo, `brewtrack-api-0.1.0-abc1234`).
- **Reducción de `web`:**
  - prueba HTTP en el puerto 8080;
  - se conservan sí o sí el contenido de la SPA, las plantillas de nginx y los scripts de arranque de la imagen oficial;
  - el usuario sigue siendo `nginx`.

  nginx resuelve `api` en cada pedido y no al arrancar, así que `web` arranca sola, sin `api` ni `db`.
- **Etiqueta:** la de la imagen normal, más `-slim`.
- **Archivado:** el `archiveArtifacts` de `reports/**` ya incluye la carpeta nueva. Los informes de `reports/slimtoolkit/` se agregan a `.gitignore`.
- **Limpieza:** el `post { always }` borra los contenedores que deja la prueba de la imagen reducida.
- No cambia el esquema, la API, la app ni la chart de Helm.

## Decisiones de pruebas

- Una buena prueba mira lo que ve el desarrollador: qué informes quedan, qué dicen, y si la imagen reducida responde. No mira cómo está escrito el script por dentro.
- **Prueba principal: una ejecución del pipeline en Jenkins.** QA comprueba que:
  - los artefactos del build traen en `reports/slimtoolkit/` los informes de `db`, `api` y `web`, con la etiqueta del build en el nombre;
  - el JSON de cada imagen es válido y lista capas con su tamaño;
  - el resumen de texto muestra el tamaño total y una línea por capa;
  - el informe de `web` compara las dos versiones, y la reducida pesa menos;
  - `brewtrack-web:<tag>-slim` existe en el registro local;
  - el deploy usó la imagen normal (`helm get values`);
  - el build termina en verde si todo pasa.
- **Prueba sin Jenkins: el script local** contra imágenes construidas en la máquina. Debe dejar los mismos archivos que Jenkins.
- **Prueba de la imagen reducida:** `docker run` de `web-slim` y `curl` a `/`, `/index.html`, una ruta interna de la SPA (debe devolver `index.html`) y `main.dart.js`, todo con 200. El contenedor corre sin root.
- **Prueba de la falla:** QA fuerza una falla en la reducción (por ejemplo, con una ruta de prueba que no existe) y comprueba que el build queda `UNSTABLE`, que el deploy corre igual y que no se publica la `-slim`.
- **Precedente:** las etapas de Semgrep y Snyk ya escriben en `reports/` con `tee`; Trivy ya corre en contenedor con el socket de Docker; el `helm test` del deploy es la prueba en vivo que no cambia.
- `pytest` y `flutter test` siguen pasando; esta spec no toca código de la app.

## Fuera de alcance

- `slim build` de `api`: depende de Postgres y de variables secretas al arrancar, y carga módulos solo cuando se usan. Se decide con los datos de `xray`.
- `slim build` de `db`: no se hará. Postgres usa archivos que una prueba HTTP no ve.
- Desplegar la imagen `web` reducida. Es una decisión aparte, después de varios builds limpios.
- Achicar los `Containerfile` (por ejemplo, juntar el `upgrade` con el resto en una sola capa). Va en otra spec, con los números de `xray`.
- Umbrales de tamaño que corten el pipeline.
- Guardar los informes en Git o en un servicio externo.
- Paneles en Grafana con el tamaño de las imágenes.

## Notas

- Cumple la constitución: no cambia el esquema ni la API, y no usa secretos.
- No publica puertos nuevos en el host. La prueba de `web-slim` usa la red interna de Docker, o un puerto libre que se cierra al terminar.
- Cifras de partida (build `addef6a`): `db` 429 MB, `api` 389 MB, `web` 165 MB.
