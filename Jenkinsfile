// CI/CD de BrewTrack: tests, Semgrep, Trivy, SlimToolkit y deploy a minikube.
// Requisitos de Jenkins: docs/ci/jenkins.md
pipeline {
  agent any
  options { timestamps(); disableConcurrentBuilds() }
  // Jenkins corre en localhost y GitHub no puede avisarle: consulta el repo cada 2 minutos.
  triggers { pollSCM('H/2 * * * *') }
  stages {
    // Tests y escaneos en paralelo: un test roto no oculta lo que encuentran Semgrep o Trivy.
    // Si cualquiera falla, no se construye ni se deploya nada.
    stage('Tests y seguridad') {
      failFast false
      parallel {
        stage('Tests API') {
          steps {
            script {
              docker.image('postgres:17.11-alpine3.24').withRun('-e POSTGRES_PASSWORD=test -e POSTGRES_DB=brewtrack_test') { pg ->
                docker.image('python:3.13.18-slim-trixie').inside("--link ${pg.id}:db -e HOME=/tmp") {
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
          agent { docker { image 'semgrep/semgrep:1.184.0'; args '--entrypoint= -e HOME=/tmp'; reuseNode true } }
          steps {
            sh '''
              semgrep scan --error --metrics=off \
                --config p/python --config p/security-audit --config p/secrets --config p/dockerfile \
                --exclude=.env --exclude=.venv --exclude=.venv-ci --exclude=.pubcache --exclude=.superpowers \
                --exclude=web/build --exclude=.dart_tool \
                api web compose.yaml
            '''
          }
        }

        stage('Trivy fs') {
          agent { docker { image 'aquasec/trivy:0.76.2'; args '--entrypoint= -u root -v trivy-cache:/root/.cache'; reuseNode true } }
          steps {
            sh '''
              trivy fs --exit-code 1 --scanners vuln,secret,misconfig --severity HIGH,CRITICAL --ignore-unfixed --quiet \
                --skip-files .env,docs/security/scan_semgrep.txt --skip-dirs '**/.venv,**/.venv-ci,.pubcache,.superpowers,web/build,**/.dart_tool' .
            '''
          }
        }
      }
    }

    stage('Build imágenes') {
      steps {
        sh '''
          docker build -t localhost/brewtrack-db:0.1.0 -f db/brewtrack-db.Containerfile db
          docker build -t localhost/brewtrack-api:0.1.0 -f api/brewtrack-api.Containerfile api
          docker build -t localhost/brewtrack-web:rebranding -f web/brewtrack-web.Containerfile web
        '''
      }
    }

    stage('Trivy imágenes') {
      agent { docker { image 'aquasec/trivy:0.76.2'; args '--entrypoint= -u root -v trivy-cache:/root/.cache -v /var/run/docker.sock:/var/run/docker.sock'; reuseNode true } }
      steps {
        sh '''
          T="trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed --quiet"
          $T --skip-files usr/local/bin/gosu localhost/brewtrack-db:0.1.0
          $T localhost/brewtrack-api:0.1.0
          $T localhost/brewtrack-web:rebranding
        '''
      }
    }

    // Tamaño y capas de cada imagen con SlimToolkit, contra un Docker 27 temporal (spec 007).
    // El script borra el Docker temporal al salir; si falta un dato, falla y no hay deploy.
    stage('SlimToolkit imágenes') {
      options { timeout(time: 15, unit: 'MINUTES') }
      steps {
        sh 'scripts/slim-analysis.sh image-analysis.md localhost/brewtrack-db:0.1.0 localhost/brewtrack-api:0.1.0 localhost/brewtrack-web:rebranding'
      }
      post { always { archiveArtifacts artifacts: 'image-analysis.md' } }
    }

    stage('Deploy minikube') {
      steps {
        // se usa el kubectl del propio nodo minikube (runtime containerd).
        sh '''
          for img in localhost/brewtrack-db:0.1.0 localhost/brewtrack-api:0.1.0 localhost/brewtrack-web:rebranding; do
            docker save "$img" | docker exec -i minikube ctr -n k8s.io images import -
          done
          V=$(docker exec minikube ls /var/lib/minikube/binaries | tail -1)
          K="docker exec -i minikube /var/lib/minikube/binaries/$V/kubectl --kubeconfig=/etc/kubernetes/admin.conf"
          $K apply -f - < k8s/brewtrack.yaml
          $K apply -f - < k8s/web-bluegreen.yaml
          $K -n brewtrack rollout restart statefulset/db deploy/api deploy/web-green
          $K -n brewtrack rollout status statefulset/db --timeout=180s
          $K -n brewtrack rollout status deploy/api --timeout=180s
          $K -n brewtrack rollout status deploy/web-green --timeout=180s
        '''
      }
    }
  }

  post {
    always { junit allowEmptyResults: true, testResults: 'api/pytest.xml' }
  }
}
