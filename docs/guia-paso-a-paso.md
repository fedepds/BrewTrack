# BrewTrack — Guía paso a paso

Esta guía explica cómo levantar BrewTrack en Kubernetes, generar tráfico para los dashboards, correr cada análisis de seguridad y borrar todo. En cada etapa muestra el comando y el resultado que se obtiene.

## Contenido

1. [Requisitos](#1-requisitos)
2. [Scripts](#2-scripts)
3. [Camino rápido: tres comandos](#3-camino-rápido-tres-comandos)
4. [Paso a paso](#4-paso-a-paso)
   - [4.1 Clúster e Ingress](#41-clúster-e-ingress)
   - [4.2 Registro local](#42-registro-local)
   - [4.3 Imágenes](#43-imágenes)
   - [4.4 Operador Kyverno](#44-operador-kyverno)
   - [4.5 Operador Falco](#45-operador-falco)
   - [4.6 BrewTrack con Helm](#46-brewtrack-con-helm)
   - [4.7 Primer admin](#47-primer-admin)
   - [4.8 Prometheus y Grafana](#48-prometheus-y-grafana)
5. [Tráfico para los dashboards](#5-tráfico-para-los-dashboards)
6. [Análisis de seguridad](#6-análisis-de-seguridad)
7. [Pipeline de Jenkins](#7-pipeline-de-jenkins)
8. [Borrar todo](#8-borrar-todo)
9. [Problemas comunes](#9-problemas-comunes)

---

## 1. Requisitos

| Herramienta | Para qué | Comprobar |
|---|---|---|
| Colima (o Docker Desktop) | motor de contenedores | `docker info` |
| minikube | clúster local | `minikube version` |
| kubectl | hablar con el clúster | `kubectl version --client` |
| Helm 3 | instalar la chart y los operadores | `helm version` |
| git, curl, openssl | scripts | — |
| Semgrep | análisis estático (opcional) | `semgrep --version` |
| Cuenta de Snyk | análisis de dependencias (opcional) | token en snyk.io |

Colima necesita recursos para el clúster, los operadores y el monitoreo:

```bash
colima start --cpu 6 --memory 10
```

---

## 2. Scripts

Todos viven en `scripts/` y se pueden correr las veces que haga falta.

| Script | Qué hace |
|---|---|
| `up.sh` | **Inicializa todo**: minikube, operador ingress-nginx, registro, imágenes, operadores Kyverno y Falco, BrewTrack, primer admin, Prometheus y Grafana. |
| `load.sh` | **Genera tráfico** contra la app para llenar los dashboards. |
| `down.sh` | **Borra todo**: BrewTrack, monitoreo, operadores y, con `--all`, el registro y el clúster. |
| `registry-up.sh` | Registro local de imágenes accesible desde minikube. |
| `kyverno-up.sh` | Instala el operador Kyverno y aplica las políticas. |
| `falco-up.sh` | Instala el operador Falco. |
| `monitoring-up.sh` | Despliega Prometheus y Grafana con el dashboard. |
| `kyverno-validate.sh` | Prueba las políticas y escribe `reports/kyverno-validation.log`. |
| `falco-event.sh` | Dispara un evento sospechoso y escribe `reports/falco-event.log`. |
| `semgrep-scan.sh` | Corre Semgrep y escribe `reports/semgrep-report.txt`. |
| `snyk-scan.sh` | Corre Snyk y escribe `reports/snyk-report.txt`. |

**Operadores de Kubernetes que se instalan**

| Operador | Cómo | Namespace | Rol |
|---|---|---|---|
| ingress-nginx | addon de minikube | `ingress-nginx` | Lleva el tráfico de afuera a la web |
| Kyverno 1.19.2 | Helm, chart `kyverno/kyverno` 3.9.2 | `kyverno` | Rechaza pods que incumplen las políticas |
| Falco 0.45.2 | Helm, chart `falcosecurity/falco` 9.2.2 | `falco` | Detecta conductas sospechosas en los pods |

---

## 3. Camino rápido: tres comandos

```bash
bash scripts/up.sh       # inicializa todo (10 a 20 minutos la primera vez)
bash scripts/load.sh     # 5 minutos de tráfico
bash scripts/down.sh     # borra todo
```

Al final, `up.sh` muestra el estado de los pods y cómo entrar:

```
===== [up] listo
NAME                                 READY   STATUS    RESTARTS   AGE
pod/brewtrack-api-…                  1/1     Running   0          …
pod/brewtrack-db-0                   1/1     Running   0          …
pod/brewtrack-web-…                  1/1     Running   0          …
pod/grafana-…                        1/1     Running   0          …
pod/prometheus-…                     1/1     Running   0          …

Web:        kubectl -n brewtrack port-forward svc/brewtrack-web 8081:8080   → http://localhost:8081
Grafana:    kubectl -n brewtrack port-forward svc/grafana 3000:3000         → http://localhost:3000
Prometheus: kubectl -n brewtrack port-forward svc/prometheus 9090:9090      → http://localhost:9090/targets
```

Para abrir la web, Grafana y Prometheus desde una sola terminal, corre los tres `port-forward` en segundo plano:

```bash
kubectl -n brewtrack port-forward svc/brewtrack-web 8081:8080 &
kubectl -n brewtrack port-forward svc/grafana 3000:3000 &
kubectl -n brewtrack port-forward svc/prometheus 9090:9090 &
```

Para cerrarlos:

```bash
pkill -f "kubectl -n brewtrack port-forward"
```

Variables de `up.sh`:

| Variable | Por defecto | Uso |
|---|---|---|
| `ADMIN_EMAIL` | `admin@brewtrack.local` | Correo del primer admin |
| `ADMIN_PASSWORD` | al azar | Clave del primer admin; queda en el Secret `brewtrack-admin` |
| `SKIP_FALCO` | `0` | `1` salta Falco si el kernel del nodo no tiene eBPF |

La sección 4 hace lo mismo que `up.sh`, una etapa por vez.

---

## 4. Paso a paso

### 4.1 Clúster e Ingress

```bash
minikube start --driver=docker --container-runtime=containerd --cpus=4 --memory=6g
minikube addons enable ingress
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=300s
```

**Resultado:**

```
$ minikube status
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured

$ kubectl -n ingress-nginx get pods
NAME                                        READY   STATUS      RESTARTS   AGE
ingress-nginx-controller-…                  1/1     Running     0          …
```

containerd es obligatorio: `registry-up.sh` lo configura para aceptar el registro local por HTTP.

### 4.2 Registro local

```bash
bash scripts/registry-up.sh
```

Levanta `registry:3.0.0` en `127.0.0.1:5001`, lo conecta a la red de minikube y lo declara como registro HTTP en containerd del nodo.

**Resultado:**

```
[registry] creando brewtrack-registry (docker.io/library/registry:3.0.0) en 127.0.0.1:5001
[registry] conectando brewtrack-registry a la red minikube
[registry] declarando brewtrack-registry:5000 como registro HTTP en containerd del nodo
[registry] listo: el nodo llega a http://brewtrack-registry:5000
```

| Desde | Dirección |
|---|---|
| El host (`docker push`) | `localhost:5001` |
| Los pods | `brewtrack-registry:5000` |

### 4.3 Imágenes

```bash
COMMIT=$(git rev-parse --short=7 HEAD)
docker build -t localhost:5001/brewtrack-db:0.1.0-$COMMIT  -f db/brewtrack-db.Containerfile db
docker build -t localhost:5001/brewtrack-api:0.1.0-$COMMIT -f api/brewtrack-api.Containerfile api
docker build -t localhost:5001/brewtrack-web:0.2.0-$COMMIT -f web/brewtrack-web.Containerfile web
for i in db:0.1.0 api:0.1.0 web:0.2.0; do docker push localhost:5001/brewtrack-${i}-$COMMIT; done
```

La etiqueta lleva el commit para que el nodo nunca reuse una imagen vieja.

**Resultado** (análisis de capas con SlimToolkit, `reports/image-analysis.md`):

| Imagen | Tamaño | Capas | De la base | Nuestras |
|---|---|---|---|---|
| `brewtrack-db:0.1.0` | 301,1 MB | 11 | 291,1 MB | 10,1 MB |
| `brewtrack-api:0.1.0` | 280,1 MB | 8 | 143,6 MB | 136,6 MB |
| `brewtrack-web:0.2.0` | 114,7 MB | 11 | 62,0 MB | 52,8 MB |

```
localhost:5001/brewtrack-api:0.1.0-31d6f23
tamaño total (suma de capas): 280.2 MB (280153614 bytes)
imagen base: docker.io/library/python:3.13-slim (10 instrucciones heredadas)

origen   capa    tamaño  agrega/cambia/borra  instrucción
base        0  100.7 MB             3266/0/0  RUN []
…
nuestra     4   41.6 MB           156/481/11  RUN apt-get update && \ apt-get upgrade -y ...
nuestra     5   94.9 MB             3199/6/0  COPY dir:87ffb5b121ad1b6075d709a97c1eec81d73...
```

La `web` reducida con `slim build` pasa de 115 MB a 55 MB:

```
web  build  info=http.probe.summary total='4' failures='0' successful='4'
web  build  info=results status='MINIFIED' by='2.07X' size.original='115 MB' size.optimized='55 MB'
```

### 4.4 Operador Kyverno

```bash
bash scripts/kyverno-up.sh
```

Instala Kyverno con Helm, aplica las cuatro políticas de `kyverno/policies/` y espera hasta que el webhook rechace un pod de prueba.

**Resultado:**

```
[kyverno] instalando Kyverno (chart 3.9.2)
[kyverno] aplicando políticas
[kyverno] esperando a que las políticas estén activas
[kyverno] listo: Kyverno ya rechaza pods que incumplen

$ kubectl get validatingpolicies
NAME                                        …
brewtrack-disallow-latest-tag
brewtrack-require-requests-limits
brewtrack-require-run-as-non-root
brewtrack-disallow-privilege-escalation
```

Se instala **antes** que BrewTrack, así la chart queda controlada desde su primer pod.

### 4.5 Operador Falco

```bash
bash scripts/falco-up.sh
```

Instala Falco con el driver `modern_ebpf` y alertas en JSON. Espera a que Falco lea eventos del kernel.

**Resultado:**

```
[falco] instalando Falco (chart 9.2.2)
daemon set "falco" successfully rolled out
[falco] listo: Falco está leyendo eventos del kernel
```

### 4.6 BrewTrack con Helm

```bash
helm upgrade --install brewtrack ./helm-chart -n brewtrack --create-namespace \
  -f helm-chart/values-dev.yaml \
  --set db.image.repository=brewtrack-registry:5000/brewtrack-db   --set db.image.tag=0.1.0-$COMMIT \
  --set api.image.repository=brewtrack-registry:5000/brewtrack-api --set api.image.tag=0.1.0-$COMMIT \
  --set web.image.repository=brewtrack-registry:5000/brewtrack-web --set web.image.tag=0.2.0-$COMMIT \
  --wait --timeout 5m
helm test brewtrack -n brewtrack --logs
kubectl -n brewtrack get pods,svc
```

**Resultado:**

```
$ helm test brewtrack -n brewtrack --logs
TEST SUITE:     brewtrack-test-health
Phase:          Succeeded
POD LOGS: brewtrack-test-health
200 {"status":"ok"}

$ kubectl -n brewtrack get pods
NAME                             READY   STATUS    RESTARTS   AGE
brewtrack-api-…                  1/1     Running   0          …
brewtrack-db-0                   1/1     Running   0          …
brewtrack-web-…                  1/1     Running   0          …
```

`helm test` hace un GET a `/api/v1/health` a través de la web: prueba nginx, el proxy y la API a la vez.

Prueba de la chart sin clúster:

```
$ bash helm-chart/tests/render.sh
… 104 controles OK
```

![Pods en Running](img/helm-pods.png)

Para entrar a la web:

```bash
kubectl -n brewtrack port-forward svc/brewtrack-web 8081:8080
```

![Web de BrewTrack](img/web.png)

### 4.7 Primer admin

La chart no trae usuarios. `up.sh` crea el admin y guarda su clave en el Secret `brewtrack-admin`:

```bash
printf '%s\n' "$ADMIN_PASSWORD" | kubectl -n brewtrack exec -i deploy/brewtrack-api -c api -- \
  python -m app.cli create-admin --email "$ADMIN_EMAIL" --name Admin
kubectl -n brewtrack create secret generic brewtrack-admin \
  --from-literal=email="$ADMIN_EMAIL" --from-literal=password="$ADMIN_PASSWORD"
```

**Resultado:**

```
Admin creado
```

Leer la clave:

```bash
kubectl -n brewtrack get secret brewtrack-admin -o jsonpath='{.data.password}' | base64 -d
```

### 4.8 Prometheus y Grafana

```bash
bash scripts/monitoring-up.sh
kubectl -n brewtrack port-forward svc/prometheus 9090:9090 &
kubectl -n brewtrack port-forward svc/grafana 3000:3000 &
```

**Resultado:**

```
[monitoring] Secret grafana creado. Clave: kubectl -n brewtrack get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d
deployment "prometheus" successfully rolled out
deployment "grafana" successfully rolled out
[monitoring] listo.
```

En http://localhost:9090/targets las dos fuentes deben estar en **UP**:

| Job | Qué trae |
|---|---|
| `api` | métricas HTTP y de negocio de la API (`/metrics`) |
| `kubernetes-cadvisor` | CPU y memoria de cada contenedor del namespace `brewtrack` |

![Targets de Prometheus](img/prometheus-targets.png)

Grafana: http://localhost:3000, usuario `admin`, clave del Secret `grafana`. El dashboard **BrewTrack** ya está cargado.

---

## 5. Tráfico para los dashboards

```bash
bash scripts/load.sh
```

Después de `up.sh` no hace falta nada más: el script lee el admin del Secret `brewtrack-admin` y abre el `port-forward` si la web no responde. Crea su propio lote de 300 kg y corre unos 5 pedidos por segundo durante 5 minutos.

| Cada 20 pedidos | Tipo | Panel que llena |
|---|---|---|
| 1 | tueste nuevo (`POST /roasts`) | Tuestes, kg tostados, merma, stock |
| 1 | login fallido (401) | Logins fallidos |
| 1 | tueste inexistente (404) | Pedidos por código |
| 17 | lecturas de lotes, tuestes y resumen | Pedidos por segundo, latencia |

| Variable | Por defecto |
|---|---|
| `DURATION` | 300 segundos |
| `RPS` | 5 pedidos por segundo |
| `BASE_URL` | `http://localhost:8081` |

**Resultado** de una corrida de prueba de 12 segundos:

```
[load 14:02:10] lote 7c1e… creado (300 kg). Corriendo 12s a ~5 pedidos/s contra http://localhost:8081
[load 14:02:22] fin: 223 pedidos, 11 tuestes nuevos, 0 errores 5xx
```

| Métrica | Valor |
|---|---|
| `brewtrack_roast_green_in_kg_total` | 117 kg |
| `brewtrack_roast_out_kg_total` | 97,339 kg → merma 16,8 % |
| `brewtrack_green_stock_kg` | 183 kg (300 − 117) |

Comprobar las métricas desde la API:

```bash
kubectl -n brewtrack port-forward deploy/brewtrack-api 8000:8000 &
curl -s localhost:8000/metrics | grep ^brewtrack_
```

Con el tráfico corriendo, el dashboard muestra:

| Sección | Qué se ve |
|---|---|
| Resumen | API arriba, ~5 pedidos/s, latencia, 0 errores 5xx, logins fallidos, stock bajando |
| Tráfico y latencia | pedidos por ruta y por código (200, 201, 401, 404), latencia p95 |
| Recursos por pod | CPU y memoria de `api`, `db` y `web` |
| Negocio | tuestes por hora, kg tostados, merma entre 12 y 20 %, tuestes por nivel |

![Dashboard de Grafana](img/grafana-dashboard.png)

---

## 6. Análisis de seguridad

### 6.1 Semgrep

```bash
bash scripts/semgrep-scan.sh
```

Prueba primero las reglas propias y después escanea el repo con las reglas de la comunidad y las propias.

**Resultado** (`reports/semgrep-report.txt`):

```
===== 1. Prueba de las reglas propias (semgrep --test)
5/5: ✓ All tests passed

===== 2. Escaneo del repo
✅ Scan completed successfully.
 • Findings: 1 (1 blocking)
 • Rules run: 698
 • Targets scanned: 153
```

El único hallazgo es un falso positivo: un hash sha256 de `pubspec.lock` que la regla confunde con un token. Detalle en `reports/semgrep-hallazgos.md`.

### 6.2 Snyk

La primera vez, guarda el token en la máquina (Snyk lo guarda en `~/.config/configstore/snyk.json`, fuera del repo):

```bash
/tmp/snyk-macos-arm64 auth
```

Desde ahí basta con:

```bash
bash scripts/snyk-scan.sh
```

Instala la API como lo hace la imagen, toma las versiones exactas con `pip freeze` y las analiza. Sale con código 1 si hay una vulnerabilidad crítica, igual que el pipeline.

En macOS y en Linux, `ci/snyk-cli.sh` baja el binario de Snyk que corresponde al sistema. Si `SNYK_TOKEN` está definido, manda sobre el token guardado.

**Resultado** (`reports/snyk-report.txt`, Snyk CLI 1.1309.0):

```
Testing  (requirements-snyk.txt) ...

Tested 36 dependencies for known issues, found 0 issues, 0 vulnerable paths.

Open Security issues: 0

│   Test type:         Software Composition Analysis                    │
│   Project name:      brewtrack-api                                    │
│   Target file:       requirements-snyk.txt                            │
│   Total security issues: 0                                            │

===== Corte del pipeline: solo vulnerabilidades críticas
Sin vulnerabilidades críticas: el pipeline sigue.
```

Control cruzado con pip-audit sobre los mismos 36 paquetes:

```
$ pip-audit -r requirements.txt --no-deps -s pypi
No known vulnerabilities found
```

### 6.3 Kyverno

```bash
bash scripts/kyverno-validate.sh
```

Aplica cada manifiesto de `kyverno/tests/` y compara lo que pasa con lo esperado.

**Resultado** (`reports/kyverno-validation.log`):

```
===== pod-root — corre como root
$ kubectl apply -f kyverno/tests/pod-root.yaml
Error from server: admission webhook "vpol.validate.kyverno.svc-fail" denied the request:
  Policy brewtrack-require-run-as-non-root failed: runAsUser 0 es root y no está permitido.
RESULTADO: rechazado (esperado: rechazado) -> OK

===== pod-ok — cumple todas las políticas
$ kubectl apply -f kyverno/tests/pod-ok.yaml
pod/pod-ok created
RESULTADO: admitido (esperado: admitido) -> OK
…
===== Resumen: 7 OK, 0 fallas
```

| Caso | Esperado | Mensaje de Kyverno |
|---|---|---|
| `pod-ok.yaml` | admitido | — |
| `pod-latest.yaml` | rechazado | "La etiqueta latest no está permitida: usa una versión fija." |
| `pod-sin-etiqueta.yaml` | rechazado | "Cada imagen tiene que llevar etiqueta…" |
| `pod-sin-limites.yaml` | rechazado | "Cada contenedor necesita resources.requests y resources.limits de cpu y memory." |
| `pod-root.yaml` | rechazado | "runAsUser 0 es root y no está permitido." |
| `pod-privilegiado.yaml` | rechazado | "Los contenedores privileged no están permitidos." |
| `deployment-malo.yaml` | rechazado | etiqueta y límites |

![Validación de Kyverno](img/kyverno-validation.png)

### 6.4 Falco

```bash
bash scripts/falco-event.sh
```

Corre `find` y `grep` dentro del pod de la API buscando llaves SSH y credenciales de AWS, y junta las alertas que genera Falco.

**Resultado** (`reports/falco-event.log`):

```
===== Acciones
$ kubectl -n brewtrack exec brewtrack-api-… -c api -- find / -xdev -name id_rsa
$ kubectl -n brewtrack exec brewtrack-api-… -c api -- grep -rl BEGIN RSA PRIVATE /etc /srv
$ kubectl -n brewtrack exec brewtrack-api-… -c api -- find / -xdev -path */.aws/credentials

===== Resumen
…  WARNING  Search Private Keys or Passwords
    pod=brewtrack-api-…  usuario=app  uid=1000  comando=find / -xdev -name id_rsa
…  WARNING  Search Private Keys or Passwords
    pod=brewtrack-api-…  usuario=app  uid=1000  comando=grep -rl BEGIN RSA PRIVATE /etc /srv
…  WARNING  Find AWS Credentials
    pod=brewtrack-api-…  usuario=app  uid=1000  comando=find / -xdev -path */.aws/credentials

Total: 3 alertas
```

Ver las alertas en vivo:

```bash
kubectl -n falco logs ds/falco -c falco -f | grep -E 'Search Private Keys|AWS Credentials'
```

![Alertas de Falco](img/falco-alertas.png)

### 6.5 Trivy

Corre dentro del pipeline (sección 7). A mano:

```bash
trivy fs --severity HIGH,CRITICAL --ignore-unfixed --skip-dirs kyverno/tests .
trivy image --severity HIGH,CRITICAL --ignore-unfixed localhost:5001/brewtrack-api:0.1.0-$COMMIT
```

**Resultado:** sin HIGH ni CRITICAL con arreglo publicado en las tres imágenes. El único riesgo aceptado es `gosu` en `db` (`docs/security/2026-11-10-imagen-db.md`).

---

## 7. Pipeline de Jenkins

Jenkins corre en el host (puertos 8080 y 50000) y consulta `master` cada 2 minutos. Instalación y credenciales: `docs/ci/jenkins.md`.

Para lanzar una corrida a mano: **Jenkins → BrewTrack → Build Now**.

| Etapa | Resultado en una corrida sana |
|---|---|
| Clonar | commit, autor y mensaje en el log |
| Tests API | todos los tests en verde, pestaña *Tests* con `pytest.xml` |
| Tests web | `No issues found!` y `All tests passed!` |
| Semgrep | 1 hallazgo, el falso positivo conocido |
| Snyk | `Sin vulnerabilidades críticas` |
| Trivy fs e imágenes | sin hallazgos HIGH o CRITICAL con arreglo |
| SlimToolkit | resumen de capas en `reports/slimtoolkit/` |
| Publicar | tres `docker push` a `localhost:5001` |
| Deploy Helm | `helm test`: `Phase: Succeeded` y pods en `Running` |

Los informes de `reports/` quedan como artefactos de cada build.

![Etapas del pipeline](img/jenkins-pipeline.png)

---

## 8. Borrar todo

```bash
bash scripts/down.sh          # BrewTrack, monitoreo y operadores; minikube sigue encendido
bash scripts/down.sh --all    # además el registro con sus imágenes y el clúster
YES=1 bash scripts/down.sh    # sin pedir confirmación
```

Orden en que borra:

| # | Qué | Cómo |
|---|---|---|
| 1 | BrewTrack | `helm uninstall brewtrack` |
| 2 | Prometheus y Grafana | `kubectl delete -f k8s/grafana.yaml -f k8s/prometheus.yaml` |
| 3 | Namespace `brewtrack` | borra el disco de la base y los Secrets que la chart conserva |
| 4 | Operador Falco | `helm uninstall falco` y namespace `falco` |
| 5 | Operador Kyverno | políticas, `helm uninstall kyverno` y namespace `kyverno` |
| 6 | Registro (`--all`) | contenedor `brewtrack-registry` y su volumen |
| 7 | Clúster (`--all`) | `minikube delete` |

**Resultado:**

```
===== [down] BrewTrack (Helm)
release "brewtrack" uninstalled
===== [down] namespace brewtrack (PVC de la base, Secrets y lo que quede)
namespace "brewtrack" deleted
===== [down] Falco
release "falco" uninstalled
===== [down] Kyverno y sus políticas
release "kyverno" uninstalled
===== [down] listo
NAME              STATUS   AGE
default           Active   …
ingress-nginx     Active   …
kube-node-lease   Active   …
kube-public       Active   …
kube-system       Active   …
```

---

## 9. Problemas comunes

| Síntoma | Causa | Solución |
|---|---|---|
| Pods en `ImagePullBackOff` | el nodo no llega al registro | `bash scripts/registry-up.sh` y revisar que diga `listo` |
| `helm install` falla con un mensaje de Kyverno | un valor rompe una política | leer el mensaje: dice qué campo falta |
| Falco no confirma la fuente de eventos | el kernel del nodo no tiene eBPF | `SKIP_FALCO=1 bash scripts/up.sh` |
| Paneles de Grafana vacíos | no hay tráfico, o Prometheus no ve la API | `bash scripts/load.sh` y revisar `/targets` |
| `load.sh` no puede entrar | falta el Secret `brewtrack-admin` | correr `up.sh` o pasar `ADMIN_EMAIL` y `ADMIN_PASSWORD` |
| El puerto 5000 está ocupado | AirPlay en macOS | el registro ya usa el 5001 |
| El pipeline corta en Deploy por recursos viejos | quedan YAML de `k8s/` aplicados | `kubectl delete -f k8s/brewtrack.yaml -f k8s/web-bluegreen.yaml` |
