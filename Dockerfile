FROM ubuntu:20.04
LABEL maintainer="ahmadkokab@processton.com"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y software-properties-common && \
    add-apt-repository -y ppa:ondrej/php && apt-get update
    
RUN apt-get update -y && apt upgrade -y && apt-get install -y --force-yes --no-install-recommends \
    build-essential \
    php8.2 \
    php8.2-fpm \
    php8.2-cli \
    php-pear \
    php-dev \
    nginx \
    libmemcached-dev \
    libfcgi-bin \
    libzip-dev \
    libz-dev \
    libzip-dev \
    libpq-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype6-dev \
    libssl-dev \
    libvips-dev \
    openssh-server \
    libmagickwand-dev \
    git \
    cron \
    nano \
    libxml2-dev \
    libreadline-dev \
    libgmp-dev \
    mariadb-client \
    unzip \
    build-essential \
    iputils-ping \
    gcc \
    g++ \
    make \
    autoconf \
    automake \
    libtool \
    python3 python3-pip \
    nasm \
    openssl \
    curl \
    sqlite3 \
    libsqlite3-dev tar ca-certificates
    
RUN apt-get install -y --no-install-recommends \
    php8.2-bcmath \
    php8.2-curl \
    php8.2-mbstring \
    php8.2-mysql \
    php8.2-tokenizer \
    php8.2-xml \
    php8.2-zip \
    php8.2-soap \
    php8.2-exif \
    php8.2-opcache \
    php8.2-gd \
    php8.2-intl \
    php8.2-gmp \
    php8.2-pgsql \
    php8.2-sqlite3 \
    php8.2-cli \
    php8.2-intl

RUN echo "soap.wsdl_cache_dir=/tmp" > /etc/php/8.2/cli/conf.d/20-soap.ini

RUN echo "exif.decode_unicode_motorola=1" > /etc/php/8.2/cli/conf.d/20-exif.ini

RUN echo "extension=exif" > /etc/php/8.2/cli/conf.d/20-exif.ini

#####################################
# Required Variables:
#####################################

RUN export NODE_OPTIONS="--no-deprecation"

ENV COMPOSER_MEMORY_LIMIT='-1'

#####################################
# Composer:
#####################################

# Install composer and add its bin to the PATH.
RUN curl -s http://getcomposer.org/installer | php && \
    echo "export PATH=${PATH}:/var/www/vendor/bin" >> ~/.bashrc && \
    mv composer.phar /usr/local/bin/composer
# Source the bash
RUN . ~/.bashrc

#####################################
# Laravel Supervisor:
#####################################

RUN apt-get install -y supervisor


#####################################
# NODE JS & YARN:
#####################################

RUN curl -sL https://deb.nodesource.com/setup_20.x | bash -

RUN apt-get install -y nodejs

RUN npm install -g npm@11.1.0

RUN npm install -g yarn

RUN yarn init -y
RUN yarn cache clean
RUN yarn set version 4.1.1

#####################################
# Git Safe Directory && Source repos:
#####################################

RUN git config --global --add safe.directory /var/www

RUN npm config set registry https://registry.npmmirror.com/

#####################################
# Files & Directories Permissions:
#####################################

RUN usermod -u 1000 www-data

COPY ./docker/nginx/ /etc/nginx/sites-available/

COPY ./docker/php/fpm.ini /etc/php/8.4/fpm/php.ini
COPY ./docker/php/cli.ini /etc/php/8.4/cli/php.ini

ADD ./docker/supervisord.conf /etc/supervisor/conf.d/worker.conf

COPY ./docker/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
RUN ln -s /usr/local/bin/docker-entrypoint.sh /
ENTRYPOINT ["docker-entrypoint.sh"]

#####################################
# Composer:
#####################################
COPY . /var/www

WORKDIR /var/www

RUN git config --global --add safe.directory /var/www
RUN COMPOSER_MEMORY_LIMIT=-1 composer install --no-interaction --no-plugins --no-dev --prefer-dist

#####################################
# YARN Setup:
#####################################

RUN npm install -g laravel-mix webpack laravel-vite-plugin vite
RUN npm install -D webpack-cli
RUN yarn install --frozen-lockfile
RUN yarn build

#####################################
# Artisan:
#####################################

RUN php artisan migrate
RUN php artisan config:clear
RUN php artisan cache:clear

#####################################
# Start Services:
#####################################

USER root

CMD ["docker-entrypoint.sh"]

EXPOSE 80