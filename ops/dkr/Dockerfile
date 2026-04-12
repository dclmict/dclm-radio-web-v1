# Dockerfile for PHP app using FrankenPHP
# Uses the pre-built DCLM base image with all extensions included.
# Build the base image first: see dkr/Dockerfile-frankenphp-base

ARG APP_SRC_DIR=code
ARG FRANKENPHP_IMAGE=img.dclmict.org/dclm/frankenphp:8.3

FROM ${FRANKENPHP_IMAGE} AS prod
ARG APP_SRC_DIR

WORKDIR /app

# Custom Caddyfile with extensionless PHP routing
COPY ./ops/php/Caddyfile /etc/caddy/Caddyfile

# Copy application code into the public directory
COPY --chown=www-data:www-data ./${APP_SRC_DIR}/ /app/public/

EXPOSE 3000
ENV SERVER_NAME=":3000"

CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
