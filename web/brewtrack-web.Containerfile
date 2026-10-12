FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

FROM docker.io/library/nginx:alpine
ENV NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1
COPY templates /etc/nginx/templates
COPY --chmod=755 docker-entrypoint.d/10-api-host.envsh /docker-entrypoint.d/10-api-host.envsh
COPY --from=build /app/build/web /usr/share/nginx/html
