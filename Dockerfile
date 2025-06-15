FROM ahmadfaryabkokab/laravel-docker:latest AS processton-carter

LABEL maintainer="ahmadkokab@processton.com"

ENV COMPOSER_MEMORY_LIMIT='-1'

RUN apt-get install -y --force-yes --no-install-recommends \
    php8.3-gd \
    sqlite3 \
    php8.3-sqlite3 \
    libsqlite3-dev

#####################################
# Laravel Schedule Cron Job:
#####################################

RUN echo "* * * * * www-data /usr/local/bin/php /var/www/artisan schedule:run >> /dev/null 2>&1"  >> /etc/cron.d/laravel-scheduler
RUN chmod 0644 /etc/cron.d/laravel-scheduler

#####################################
# Files & Directories Permissions:
#####################################

RUN rm -r /var/lib/apt/lists/*

RUN usermod -u 1000 www-data

RUN rm -rf /var/www/html

COPY ./docker/nginx/default.conf /etc/nginx/sites-available/default

COPY ./docker/php/fpm.ini /etc/php/8.3/fpm/php.ini
COPY ./docker/php/cli.ini /etc/php/8.3/cli/php.ini

WORKDIR /var/www

COPY --chown=www-data:www-data . /var/www

ADD docker/supervisord.conf /etc/supervisor/conf.d/worker.conf
COPY ./docker/docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
RUN ln -s /usr/local/bin/docker-entrypoint.sh /
ENTRYPOINT ["docker-entrypoint.sh"]

#####################################
# Composer:
#####################################

RUN git config --global --add safe.directory /var/www
RUN COMPOSER_MEMORY_LIMIT=-1 composer install --no-interaction --no-plugins --no-dev --prefer-dist

#####################################
# YARN Setup:
#####################################

RUN npm install -g laravel-mix webpack laravel-vite-plugin vite
RUN npm install -D webpack-cli
RUN yarn
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

RUN service nginx start
RUN service php8.3-fpm start

EXPOSE 80