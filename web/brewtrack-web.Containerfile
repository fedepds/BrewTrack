FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

FROM docker.io/library/nginx:alpine
ENV NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1
COPY templates /etc/nginx/templates
COPY --from=build /app/build/web /usr/share/nginx/html

# Sin root: el puerto 8080 no necesita privilegios; el pid va a /tmp y nginx
# escribe solo en su caché y en conf.d (donde el entrypoint genera default.conf).
RUN sed -i -e '/^user /d' -e 's#/run/nginx.pid#/tmp/nginx.pid#' /etc/nginx/nginx.conf \
 && chown -R nginx:nginx /var/cache/nginx /etc/nginx/conf.d
USER nginx
EXPOSE 8080
