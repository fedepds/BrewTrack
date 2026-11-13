FROM docker.io/library/python:3.13-slim AS build
WORKDIR /src
COPY pyproject.toml ./
COPY app ./app
RUN pip install --no-cache-dir --prefix=/install .

FROM docker.io/library/python:3.13-slim
# Trivy: parches de Debian y fuera pip (trae msgpack, urllib3 y setuptools vulnerables; en ejecución no hace falta).
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/* \
 && pip uninstall -y pip setuptools \
 && useradd --create-home --uid 1000 app
COPY --from=build /install /usr/local
WORKDIR /srv
COPY alembic.ini ./
COPY alembic ./alembic
USER app
EXPOSE 8000
CMD ["sh", "-c", "alembic upgrade head && exec uvicorn app.main:app --host 0.0.0.0 --port 8000"]
