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

# Copy composer files first for caching
COPY --chown=www-data:www-data composer.json composer.lock /var/www/html/

USER www-data
# RUN composer install --no-dev --optimize-autoloader --no-interaction
RUN composer install --optimize-autoloader --no-interaction

# Now copy the rest of the app
COPY --chown=www-data:www-data . /var/www/html
# ============================================================
# Production stage (simpler, no UID/GID remapping)
# ============================================================
FROM base AS production

USER root

RUN install-php-extensions intl

# Copy composer files first for caching
COPY --chown=www-data:www-data composer.json composer.lock /var/www/html/

USER www-data
# RUN composer install --no-dev --optimize-autoloader --no-interaction

# Don't run scripts or autoloader generation before copying the app
RUN composer install --no-dev --no-scripts --no-autoloader --no-interaction


# Now copy the rest of the app
COPY --chown=www-data:www-data . /var/www/html

# Now run scripts and autoloader generation
RUN composer dump-autoload --optimize && \
  composer run-script post-autoload-dump
