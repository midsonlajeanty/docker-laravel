ARG SERVERSIDEUP_PHP_VERSION=8.5-fpm-nginx-alpine

ARG NGINX_VERSION=1.31.0-r1

ARG USER_ID=9999
ARG GROUP_ID=9999

# =================================================================
# Stage: base
# =================================================================
FROM serversideup/php:${SERVERSIDEUP_PHP_VERSION} AS base

ARG USER_ID
ARG GROUP_ID
ARG NGINX_VERSION

WORKDIR /var/www/html

USER root

# Install patched Nginx from the official nginx.org Alpine repository
RUN set -eux; \
    apk add --no-cache ca-certificates curl; \
    NGINX_ALPINE_VERSION="$(egrep -o '^[0-9]+\.[0-9]+' /etc/alpine-release)"; \
    NGINX_REPOSITORY="https://nginx.org/packages/mainline/alpine/v${NGINX_ALPINE_VERSION}/main"; \
    sed -i 's|http://nginx.org/packages|https://nginx.org/packages|g' /etc/apk/repositories; \
    grep -qxF "@nginx ${NGINX_REPOSITORY}" /etc/apk/repositories || echo "@nginx ${NGINX_REPOSITORY}" >> /etc/apk/repositories; \
    curl -fsSL https://nginx.org/keys/nginx_signing.rsa.pub -o /etc/apk/keys/nginx_signing.rsa.pub; \
    apk add --no-cache --upgrade "nginx@nginx=${NGINX_VERSION}"; \
    rm -f /etc/nginx/nginx.conf /etc/nginx/conf.d/default.conf; \
    nginx -v

RUN docker-php-serversideup-set-id www-data $USER_ID:$GROUP_ID && \
    docker-php-serversideup-set-file-permissions --owner $USER_ID:$GROUP_ID --service nginx

RUN apk upgrade --no-cache && \
    apk add --no-cache \
    git \
    git-lfs \
    jq \
    lsof

RUN install-php-extensions sockets pcntl

RUN echo "alias ll='ls -al'" >> /etc/profile && \
    echo "alias a='php artisan'" >> /etc/profile && \
    echo "alias logs='tail -f storage/logs/laravel.log'" >> /etc/profile

COPY docker/common/etc/nginx/conf.d/custom.conf /etc/nginx/conf.d/custom.conf
COPY docker/common/etc/nginx/site-opts.d/http.conf /etc/nginx/site-opts.d/http.conf

COPY --chmod=755 docker/common/etc/s6-overlay/ /etc/s6-overlay/

RUN mkdir -p /etc/nginx/conf.d && \
    chown -R www-data:www-data /etc/nginx && \
    chmod -R 755 /etc/nginx

# =================================================================
# Stage: development
# =================================================================
FROM base AS development

COPY docker/development/etc/php/conf.d/zzz-custom-php.ini /usr/local/etc/php/conf.d/zzz-custom-php.ini
ENV PHP_OPCACHE_ENABLE=0

USER www-data

# =================================================================
# Stage: production
# =================================================================
FROM base AS production

COPY docker/production/etc/php/conf.d/zzz-custom-php.ini /usr/local/etc/php/conf.d/zzz-custom-php.ini
ENV PHP_OPCACHE_ENABLE=1

USER www-data
