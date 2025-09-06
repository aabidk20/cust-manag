# Base image (same as your serversideup variant)
FROM registry.aabidk.dev/php:8.4.11-fpm-nginx-alpine3.21-v3.6.0 AS base

ENV PHP_OPCACHE_ENABLE=1

# ============================================================
# Development stage (fixes host UID/GID permissions)
# ============================================================
FROM base AS development

USER root

# Accept host UID/GID at build time
ARG USER_ID=1000
ARG GROUP_ID=1000

# Install needed extensions
RUN install-php-extensions intl

# Align www-data UID/GID with host, only in development since we are using bind mounts
# This ensures that files created by www-data inside the container have the same ownership as the host user and vice versa, preventing permission issues when using bind mounts.

RUN docker-php-serversideup-set-id www-data $USER_ID:$GROUP_ID \
    && docker-php-serversideup-set-file-permissions --owner $USER_ID:$GROUP_ID --service nginx

# Copy code
COPY --chown=www-data:www-data . /var/www/html

USER www-data

RUN composer install --no-dev --optimize-autoloader --no-interaction

# ============================================================
# Production stage (simpler, no UID/GID remapping)
# ============================================================
FROM base AS production

USER root

RUN install-php-extensions intl

COPY --chown=www-data:www-data . /var/www/html

USER www-data

RUN composer install --no-dev --optimize-autoloader --no-interaction

