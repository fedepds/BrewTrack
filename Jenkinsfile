// CI/CD de BrewTrack: clona, analiza (Semgrep, Snyk, Trivy, SlimToolkit), prueba, construye, publica en el registro local y despliega con Helm.
// Requisitos de Jenkins y cómo levantarlo: docs/ci/jenkins.md
pipeline {
  agent any
  options {
    timestamps()
    disableConcurrentBuilds()
    // La clonación es una etapa propia, para que su registro quede aparte.
    skipDefaultCheckout()
  }
  // Jenkins corre en localhost y GitHub no puede avisarle: consulta el repo cada 2 minutos.
  triggers { pollSCM('H/2 * * * *') }

  parameters {
    // Rutas que la imagen web reducida debe servir con 200. QA puede poner una que no exista para forzar la falla.
    string(name: 'WEB_CHECK_PATHS', defaultValue: '/ /index.html /lotes/ejemplo /main.dart.js', description: 'Rutas que prueba la imagen web reducida (spec 010)')
  }

  environment {
    // Registro local (scripts/registry-up.sh): el host publica en PUSH_REGISTRY y los pods bajan de PULL_REGISTRY.
    PUSH_REGISTRY = 'localhost:5001'
    PULL_REGISTRY = 'brewtrack-registry:5000'
    DB_VERSION  = '0.1.0'
    API_VERSION = '0.1.0'
    WEB_VERSION = '0.2.0'
    HELM_IMAGE  = 'docker.io/alpine/helm:3.19.0'
    // "stable" o una versión fija de la CLI de Snyk, por ejemplo "v1.1300.0".
    SNYK_CLI_VERSION = 'stable'
  }

  stages {
    stage('Clonar repositorio') {
      steps {
        checkout scm
        script {
          env.GIT_SHORT = sh(script: 'git rev-parse --short=7 HEAD', returnStdout: true).trim()
          // Etiqueta única por commit: con "IfNotPresent", repetir una etiqueta dejaría la imagen vieja en el nodo.
          env.DB_TAG  = "${env.DB_VERSION}-${env.GIT_SHORT}"
          env.API_TAG = "${env.API_VERSION}-${env.GIT_SHORT}"
          env.WEB_TAG = "${env.WEB_VERSION}-${env.GIT_SHORT}"
        }
        sh 'git log -1 --format="commit %H%nautor  %an%nfecha  %ad%n%n%s"; mkdir -p reports'
      }
    }

    // Tests y escaneos en paralelo: un test roto no oculta lo que encuentran Semgrep, Snyk o Trivy.
    // Si cualquiera falla, no se construye ni se despliega nada.
    stage('Tests y seguridad') {
      failFast false
      parallel {
        stage('Tests API') {
          steps {
            script {
              docker.image('postgres:17-alpine').withRun('-e POSTGRES_PASSWORD=test -e POSTGRES_DB=brewtrack_test') { pg ->
                docker.image('python:3.13-slim').inside("--link ${pg.id}:db -e HOME=/tmp") {
                  sh '''
                    cd api
                    python -m venv .venv-ci && . .venv-ci/bin/activate
                    pip install -q -e '.[dev]'
                    export DATABASE_URL=postgresql+psycopg://postgres:test@db:5432/brewtrack_test
                    until python -c "import psycopg; psycopg.connect('postgresql://postgres:test@db:5432/brewtrack_test')" 2>/dev/null; do sleep 1; done
                    pytest --junitxml=pytest.xml
                  '''
                }
              }
            }
          }
        }

        stage('Tests web') {
          agent { docker { image 'ghcr.io/cirruslabs/flutter:3.44.0'; args '-u root'; reuseNode true } }
          steps {
            // El SDK es de root; al final se devuelve el workspace al usuario de Jenkins.
            sh '''
              cd web
              set +e
              flutter pub get && flutter analyze && flutter test
              rc=$?
              chown -R 1000:1000 .
              exit $rc
            '''
          }
        }

        stage('Semgrep') {
          agent { docker { image 'semgrep/semgrep'; args '--entrypoint= -e HOME=/tmp'; reuseNode true } }
          steps {
            // --error corta el pipeline si hay hallazgos; tee deja el informe en reports/ además del log.
            sh '''
              set -o pipefail
              semgrep scan --error --metrics=off \
                --config p/python --config p/security-audit --config p/secrets --config p/dockerfile \
                --config semgrep/python-security.yaml \
                --exclude=.env --exclude=.venv --exclude=.venv-ci --exclude=.pubcache --exclude=.superpowers \
                --exclude=web/build --exclude=.dart_tool --exclude=semgrep/python-security.py \
                api web compose.yaml 2>&1 | tee reports/semgrep-report.txt
            '''
          }
        }

        stage('Snyk dependencias') {
          agent { docker { image 'python:3.13-slim'; args '-e HOME=/tmp'; reuseNode true } }
          steps {
            withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
              sh '''#!/bin/bash
                set -euo pipefail
                . ci/snyk-cli.sh
                # Snyk lee las versiones reales de un entorno instalado: se instala la API y se congelan sus dependencias.
                python -m venv /tmp/venv-snyk && . /tmp/venv-snyk/bin/activate
                pip install -q ./api
                pip freeze --exclude-editable | grep -vi '^brewtrack-api' > api/requirements-snyk.txt
                cd api
                # Corta solo ante vulnerabilidades críticas; el resto queda en el informe.
                "$SNYK" test --file=requirements-snyk.txt --package-manager=pip --command=python \
                  --project-name=brewtrack-api --severity-threshold=critical 2>&1 | tee ../reports/snyk-report.txt
              '''
            }
          }
        }

        stage('Trivy fs') {
          agent { docker { image 'aquasec/trivy'; args '--entrypoint= -u root -v trivy-cache:/root/.cache'; reuseNode true } }
          steps {
            sh '''
              # kyverno/tests trae manifiestos que incumplen a propósito (casos de prueba de las políticas).
              trivy fs --exit-code 1 --scanners vuln,secret,misconfig --severity HIGH,CRITICAL --ignore-unfixed --quiet \
                --skip-files .env,docs/security/scan_semgrep.txt,reports/semgrep-report.txt \
                --skip-dirs '**/.venv,**/.venv-ci,.pubcache,.superpowers,web/build,**/.dart_tool,kyverno/tests' .
            '''
          }
        }
      }
    }

    stage('Build imágenes') {
      steps {
        sh '''
          docker build -t "$PUSH_REGISTRY/brewtrack-db:$DB_TAG"   -f db/brewtrack-db.Containerfile db
          docker build -t "$PUSH_REGISTRY/brewtrack-api:$API_TAG" -f api/brewtrack-api.Containerfile api
          docker build -t "$PUSH_REGISTRY/brewtrack-web:$WEB_TAG" -f web/brewtrack-web.Containerfile web
          docker image ls --format 'table {{.Repository}}:{{.Tag}}\t{{.Size}}' | grep -E "brewtrack-(db|api|web):($DB_TAG|$API_TAG|$WEB_TAG)"
        '''
      }
    }

    // Spec 010: imagen web reducida. Falla = build UNSTABLE; el deploy sigue con la imagen normal.
    stage('Reducir web (SlimToolkit)') {
      steps {
        catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
          sh 'ci/slimtoolkit.sh reduce "$PUSH_REGISTRY/brewtrack-web:$WEB_TAG"'
          script { env.SLIM_BUILT = 'true' }
        }
      }
    }

    stage('Trivy web reducida') {
      when { beforeAgent true; environment name: 'SLIM_BUILT', value: 'true' }
      steps {
        catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
          script {
            docker.image('aquasec/trivy').inside('--entrypoint= -u root -v trivy-cache:/root/.cache -v /var/run/docker.sock:/var/run/docker.sock') {
              sh 'trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed --quiet "$PUSH_REGISTRY/brewtrack-web:$WEB_TAG-slim"'
            }
            env.SLIM_OK = 'true'
          }
        }
      }
    }

    stage('Escaneo de imágenes') {
      failFast false
      parallel {
        stage('Trivy imágenes') {
          agent { docker { image 'aquasec/trivy'; args '--entrypoint= -u root -v trivy-cache:/root/.cache -v /var/run/docker.sock:/var/run/docker.sock'; reuseNode true } }
          steps {
            // Escanea las tres aunque falle una; tee deja el informe en reports/ además del log.
            sh '''#!/bin/sh
              set -o pipefail
              R=reports/trivy-images-report.txt; : > "$R"; rc=0
              T="trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed --quiet"
              for args in "--skip-files usr/local/bin/gosu $PUSH_REGISTRY/brewtrack-db:$DB_TAG" \
                          "$PUSH_REGISTRY/brewtrack-api:$API_TAG" "$PUSH_REGISTRY/brewtrack-web:$WEB_TAG"; do
                echo "===== ${args##* }" | tee -a "$R"
                $T $args 2>&1 | tee -a "$R" || rc=1
              done
              exit $rc
            '''
          }
        }

        stage('SlimToolkit análisis') {
          // Solo informa: si falla, la etapa queda UNSTABLE y el pipeline sigue.
          steps {
            catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
              sh 'ci/slimtoolkit.sh xray "$PUSH_REGISTRY/brewtrack-db:$DB_TAG" "$PUSH_REGISTRY/brewtrack-api:$API_TAG" "$PUSH_REGISTRY/brewtrack-web:$WEB_TAG"'
            }
          }
        }
      }
    }

    stage('Publicar imágenes') {
      steps {
        sh '''
          bash scripts/registry-up.sh
          for img in "brewtrack-db:$DB_TAG" "brewtrack-api:$API_TAG" "brewtrack-web:$WEB_TAG"; do
            docker push "$PUSH_REGISTRY/$img"
          done
          # La reducida sube solo si pasó la prueba y Trivy. El deploy no la usa.
          if [ "${SLIM_OK:-}" = true ]; then docker push "$PUSH_REGISTRY/brewtrack-web:$WEB_TAG-slim"; fi
        '''
      }
    }

    stage('Deploy Helm') {
      steps {
        script {
          // kubectl del propio nodo de minikube: sirve para las comprobaciones previas y para sacar el kubeconfig.
          def k = 'docker exec -i minikube /var/lib/minikube/binaries/$(docker exec minikube ls /var/lib/minikube/binaries | tail -1)/kubectl --kubeconfig=/etc/kubernetes/admin.conf'

          // Los YAML viejos de k8s/ (api, db, web-blue, web-green) no chocan por nombre con la chart (brewtrack-*),
          // pero dejarían una segunda base corriendo. Se corta con un mensaje en vez de borrarlos sin avisar.
          def legacy = sh(script: "${k} -n brewtrack get deploy/api statefulset/db --ignore-not-found -o name", returnStdout: true).trim()
          if (legacy) {
            error("Quedan recursos de los YAML de k8s/ en el namespace brewtrack (${legacy.replace('\n', ', ')}). Bórralos una vez: kubectl delete -f k8s/brewtrack.yaml -f k8s/web-bluegreen.yaml")
          }

          sh 'docker exec minikube cat /etc/kubernetes/admin.conf > .kubeconfig && chmod 600 .kubeconfig'
          def nodeIp = sh(script: "docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' minikube | awk '{print \$1}'", returnStdout: true).trim()

          // Helm corre en un contenedor en la red de minikube; el kubeconfig apunta a control-plane.minikube.internal.
          docker.image(env.HELM_IMAGE).inside("--entrypoint= --network minikube --add-host control-plane.minikube.internal:${nodeIp} -e HOME=/tmp") {
            sh """
              export KUBECONFIG=\$PWD/.kubeconfig
              helm lint ./helm-chart -f helm-chart/values-dev.yaml
              # Las imágenes se bajan del registro local con la etiqueta de este build.
              helm upgrade --install brewtrack ./helm-chart -n brewtrack --create-namespace \
                -f helm-chart/values-dev.yaml \
                --set db.image.repository=${env.PULL_REGISTRY}/brewtrack-db  --set db.image.tag=${env.DB_TAG} \
                --set api.image.repository=${env.PULL_REGISTRY}/brewtrack-api --set api.image.tag=${env.API_TAG} \
                --set web.image.repository=${env.PULL_REGISTRY}/brewtrack-web --set web.image.tag=${env.WEB_TAG} \
                --wait --timeout 5m
              # GET a /api/v1/health a través de web: prueba web, el proxy de nginx y la API.
              helm test brewtrack -n brewtrack --logs --timeout 2m
              helm -n brewtrack status brewtrack
              helm -n brewtrack history brewtrack --max 5
            """
          }
          sh "${k} -n brewtrack get pods,svc,ingress -o wide"
        }
      }
    }
  }

  post {
    always {
      junit allowEmptyResults: true, testResults: 'api/pytest.xml'
      archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
      // El dind de SlimToolkit se borra solo al salir el script; esto cubre un corte brusco. La -slim ya está en el registro o no se publica: no se guarda en el host.
      sh 'docker rm -f brewtrack-slim-dind >/dev/null 2>&1 || true; docker rmi "$PUSH_REGISTRY/brewtrack-web:$WEB_TAG-slim" >/dev/null 2>&1 || true; rm -rf .kubeconfig api/requirements-snyk.txt'
    }
    failure {
      echo 'El pipeline falló: revisa la etapa en rojo y los informes en reports/ (Semgrep, Snyk, Trivy).'
    }
  }
}
