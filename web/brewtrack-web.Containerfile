FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release --no-web-resources-cdn

FROM docker.io/library/nginx:1.31.8-alpine
ENV NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1
ENV API_UPSTREAM=http://api:8000
COPY templates /etc/nginx/templates
COPY --from=build /app/build/web /usr/share/nginx/html

# Trivy: parches de Alpine (brotli, curl) que la imagen base aún no trae.
RUN apk upgrade --no-cache \
 && sed -i -e '/^user /d' -e 's#/run/nginx.pid#/tmp/nginx.pid#' /etc/nginx/nginx.conf \
 && chown -R nginx:nginx /var/cache/nginx /etc/nginx/conf.d
USER nginx
EXPOSE 8080
