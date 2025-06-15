FROM ahmadfaryabkokab/laravel-docker:latest

LABEL maintainer="ahmadkokab@processton.com"

ENV COMPOSER_MEMORY_LIMIT='-1'

#####################################
# Required Variables:
#####################################

RUN export NODE_OPTIONS="--no-deprecation"

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