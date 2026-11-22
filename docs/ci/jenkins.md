# Jenkins para BrewTrack

El `Jenkinsfile` de la raíz clona el repo, analiza el código y las dependencias, corre los tests, construye las imágenes, las publica en el registro local y despliega en minikube con Helm. Si una etapa falla, las siguientes no corren.

## Etapas

| # | Etapa | Herramienta | Corta el pipeline si… | Deja |
|---|---|---|---|---|
| 1 | Clonar repositorio | git (`checkout scm`) | no puede clonar | commit, autor y mensaje en el log |
| 2a | Tests API | pytest + Postgres 17 | falla un test | `api/pytest.xml` (pestaña Tests) |
| 2b | Tests web | flutter analyze + flutter test | hay errores de análisis o falla un test | log |
| 2c | Semgrep | Semgrep (`p/python`, `p/security-audit`, `p/secrets`, `p/dockerfile`) | hay cualquier hallazgo | `reports/semgrep-report.txt` |
| 2d | Snyk dependencias | Snyk CLI sobre las dependencias de la API | hay una vulnerabilidad **crítica** | `reports/snyk-report.txt` |
| 2e | Trivy fs | Trivy (vulnerabilidades, secretos, configuración) | hay hallazgos HIGH o CRITICAL con arreglo | log |
| 3 | Build imágenes | docker build | falla una compilación | tamaño de cada imagen en el log |
| 4a | Trivy imágenes | Trivy | hay hallazgos HIGH o CRITICAL con arreglo | log |
| 4b | Snyk imágenes | `snyk container test` | hay una vulnerabilidad **crítica** | `reports/snyk-container-report.txt` |
| 5 | Publicar imágenes | docker push a `localhost:5001` | el registro no responde | imágenes en el registro |
| 6 | Deploy Helm | `helm upgrade --install --wait` y `helm test` | un pod no queda listo en 5 minutos, o `/api/v1/health` no responde a través de la web | `helm status`, salida del test, historial y pods en el log |

Las etapas 2 y 4 corren en paralelo y sin `failFast`: si falla una, las demás terminan igual, así se ven todos los problemas de una vez.

Cada build etiqueta las imágenes con la versión y el commit (`0.1.0-<commit corto>`). Con una etiqueta repetida y `imagePullPolicy: IfNotPresent`, el nodo seguiría con la imagen vieja.

Los informes de `reports/` quedan como artefactos de cada build (Build → *Artifacts*).

## Requisitos

**Plugins:** Pipeline, Git, Docker Pipeline, JUnit, Timestamper y Credentials Binding.

**Docker:** Jenkins tiene que poder correr `docker` contra el mismo daemon que levantó minikube (en Colima, el de `colima start`). Si Jenkins corre en un contenedor, móntale `/var/run/docker.sock` e instálale el cliente `docker`.

**Credencial `snyk-token`:** tipo *Secret text*, con el token de la cuenta de Snyk (snyk.io → *Account settings* → *Auth Token*). Se carga en *Manage Jenkins → Credentials → System → Global*. El pipeline nunca imprime el token.

## Antes del primer build

```sh
colima start
minikube start --driver=docker --container-runtime=containerd
minikube addons enable ingress

# Registro local en localhost:5001 y containerd del nodo listo para bajar de brewtrack-registry:5000.
scripts/registry-up.sh

# Solo si antes se aplicaron los YAML de k8s/ a mano: dejarían una segunda base corriendo.
kubectl delete -f k8s/brewtrack.yaml -f k8s/web-bluegreen.yaml --ignore-not-found
```

`scripts/registry-up.sh` se puede correr las veces que haga falta; el pipeline también lo corre antes de publicar.

## Cómo llega una imagen al clúster

```
Jenkins ──docker push──▶ localhost:5001 ─┐
                                         ├─ contenedor brewtrack-registry (registry:3.0.0)
nodo minikube ──pull──▶ brewtrack-registry:5000 ─┘   (red Docker "minikube")
```

El registro habla HTTP. `registry-up.sh` declara ese host en containerd del nodo (`/etc/containerd/certs.d/brewtrack-registry:5000/hosts.toml`). Si se recrea minikube (`minikube delete`), hay que volver a correrlo.

## Problemas comunes

| Síntoma | Causa | Arreglo |
|---|---|---|
| Deploy Helm: "Quedan recursos de los YAML de k8s/" | quedan `deploy/api` o `statefulset/db` de `k8s/*.yaml` | `kubectl delete -f k8s/brewtrack.yaml -f k8s/web-bluegreen.yaml` y volver a correr |
| `helm test` falla | la web no llega a la API | `kubectl -n brewtrack logs brewtrack-test-health` y `kubectl -n brewtrack logs deploy/brewtrack-web` |
| Pods en `ImagePullBackOff` con `http: server gave HTTP response to HTTPS client` | containerd del nodo no conoce el registro HTTP | `scripts/registry-up.sh` |
| Snyk: `falta la credencial snyk-token` | no se cargó la credencial | crearla como *Secret text* con ese ID |
| Snyk sale con código 1 | hay una vulnerabilidad crítica | ver `reports/snyk-report.txt`, subir la versión de la dependencia en `api/pyproject.toml` |
| Deploy Helm: `context deadline exceeded` | un pod no quedó listo | `kubectl -n brewtrack get pods` y `kubectl -n brewtrack describe pod <pod>` |
