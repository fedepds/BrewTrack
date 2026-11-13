// CI de BrewTrack: tests unitarios de API y web.
pipeline {
  agent any

  stages {
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
                pytest
              '''
            }
          }
        }
      }
    }

    stage('Tests web') {
      agent { docker { image 'ghcr.io/cirruslabs/flutter:stable'; args '-u root'; reuseNode true } }
      steps {
        // El SDK es de root; al final se devuelve el workspace al usuario de Jenkins.
        sh '''
          cd web
          set +e
          flutter pub get && flutter test
          rc=$?
          chown -R 1000:1000 .
          exit $rc
        '''
      }
    }
  }
}
