FROM php:8.1-fpm
LABEL maintainer="ahmadkokab@processton.com"

# Install system dependencies and Nginx
RUN apt-get update && apt-get install -y \
    nginx supervisor git unzip curl nano cron mariadb-client \
    build-essential libmemcached-dev libfcgi-bin libzip-dev libz-dev libpq-dev \
    libjpeg-dev libpng-dev libfreetype6-dev libssl-dev libvips-dev libmagickwand-dev \
    libxml2-dev libreadline-dev libgmp-dev iputils-ping gcc g++ make autoconf automake libtool \
    python3 python3-pip nasm openssl sqlite3 libsqlite3-dev tar ca-certificates pkg-config \
    libonig-dev \
    && rm -rf /var/lib/apt/lists/*

# Install PHP extensions (some are built-in or enabled by default)
RUN set -ex \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install bcmath \
    && docker-php-ext-install mbstring \
    && docker-php-ext-install pdo \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install xml \
    && docker-php-ext-install zip \
    && docker-php-ext-install soap \
    && docker-php-ext-install exif \
    && docker-php-ext-install gd \
    && docker-php-ext-install intl \
    && docker-php-ext-install gmp \
    && docker-php-ext-install pgsql \
    && docker-php-ext-install pdo_pgsql \
    && docker-php-ext-install pdo_sqlite
    
# Install Composer
RUN curl -sS https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/composer

# Install Node.js 20.x and Yarn
RUN curl -sL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update && apt-get install -y nodejs \
    && npm install -g npm@11.4.2

# Set up Nginx and PHP configs
COPY ./docker/nginx/default.conf /etc/nginx/sites-available/default
COPY ./docker/php/fpm.ini /usr/local/etc/php/conf.d/fpm.ini
COPY ./docker/php/cli.ini /usr/local/etc/php/conf.d/cli.ini
COPY ./docker/supervisord.conf /etc/supervisor/conf.d/worker.conf

# Entrypoint
COPY ./docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh && ln -s /usr/local/bin/docker-entrypoint.sh /
ENTRYPOINT ["docker-entrypoint.sh"]

# Set working directory and copy app
WORKDIR /var/www
COPY --chown=www-data:www-data . /var/www

RUN cp .env.example .env
# Install PHP and JS dependencies, build assets
RUN composer install --no-interaction --no-plugins --no-dev --prefer-dist
RUN npm ci && npm run build

# Laravel setup
RUN php artisan migrate --force && php artisan config:clear && php artisan cache:clear

USER root
EXPOSE 80
CMD ["docker-entrypoint.sh"]
