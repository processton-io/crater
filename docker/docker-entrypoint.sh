#!/bin/bash

# Set correct permissions and ownership for storage directory
chown -R www-data:www-data /var/www/storage
chmod -R 775 /var/www/storage

chown -R www-data:www-data /var/www/bootstrap/cache
chmod -R 775 /var/www/bootstrap/cache

chown www-data:www-data /var/www/.env
chmod 775 /var/www/.env

chown www-data:www-data /var/www/database/database.sqlite
chmod 775 /var/www/database/database.sqlite


# important laravel commands
php /var/www/artisan config:cache
php /var/www/artisan route:cache
php /var/www/artisan view:cache
php /var/www/artisan storage:link
php /var/www/artisan migrate --force


service nginx start
service supervisor start

php-fpm -F
