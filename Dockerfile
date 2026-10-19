# syntax=docker/dockerfile:1

############################
# 1) Build des assets (Laravel Mix)
############################
FROM node:18-bullseye AS assets
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# Variables MIX_* : figees dans le bundle au moment du build
ARG MIX_GOOGLE_MAP_API_KEY
ARG MIX_GOOGLE_CLIENT_ID
ENV MIX_GOOGLE_MAP_API_KEY=${MIX_GOOGLE_MAP_API_KEY} \
    MIX_GOOGLE_CLIENT_ID=${MIX_GOOGLE_CLIENT_ID} \
    NODE_OPTIONS=--openssl-legacy-provider

RUN npm run prod

############################
# 2) Image applicative PHP-FPM
############################
FROM php:8.1-fpm AS app

USER root
WORKDIR /var/www

# Dependances et extensions (identiques a l'ancien Dockerfile, sans nodejs/npm)
RUN apt update && apt install -y \
        libpng-dev \
        libjpeg-dev \
        libfreetype6-dev \
        zlib1g-dev \
        libxml2-dev \
        libzip-dev \
        libonig-dev \
        zip \
        curl \
        unzip \
        libsodium-dev \
        cron \
        exiftool \
        libmagickwand-dev \
        imagemagick \
        supervisor \
    && docker-php-ext-install -j$(nproc) gd \
        pdo_mysql \
        mysqli \
        zip \
        pcntl \
        sodium \
        exif \
    && pecl install imagick \
        redis \
    && docker-php-ext-enable exif \
        imagick \
    && docker-php-source delete

RUN mkdir -p /usr/src/php/ext/redis \
       && curl -L https://github.com/phpredis/phpredis/archive/5.3.4.tar.gz | tar xvz -C /usr/src/php/ext/redis --strip 1 \
       && echo 'redis' >> /usr/src/php-available-exts \
       && docker-php-ext-install redis \
       && docker-php-ext-enable redis \
       && docker-php-ext-install soap \
       && docker-php-ext-enable soap \
       && docker-php-ext-configure gd --with-freetype --with-jpeg \
       && docker-php-ext-install -j$(nproc) gd \
    && rm -rf /var/lib/apt/lists/*

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
 && sed -i "s/max_execution_time = 30/max_execution_time = 60/g" /usr/local/etc/php/php.ini \
 && sed -i "s/post_max_size = 8M/post_max_size = 60M/g" /usr/local/etc/php/php.ini \
 && sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 40M/g" /usr/local/etc/php/php.ini

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

COPY ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xml
COPY docker/zz-pool.conf /usr/local/etc/php-fpm.d/zz-pool.conf

# Dependances PHP (couche mise en cache tant que composer.lock ne change pas)
COPY composer.json composer.lock ./
RUN composer install --no-interaction --prefer-dist --no-scripts --no-autoloader

# Code applicatif + assets compiles
COPY . .
COPY --from=assets /app/public ./public

RUN composer dump-autoload --optimize --no-scripts \
 && mkdir -p storage/app/public storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
 && ln -sfn /var/www/storage/app/public public/storage \
 && chown -R www-data:www-data storage bootstrap/cache

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 9000
ENTRYPOINT ["entrypoint.sh"]
CMD ["php-fpm"]

############################
# 3) Serveur web Caddy (HTTPS automatique) avec les fichiers publics
############################
FROM caddy:2-alpine AS web
COPY docker/Caddyfile /etc/caddy/Caddyfile
COPY --from=app /var/www/public /var/www/public
