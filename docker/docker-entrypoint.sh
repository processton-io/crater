#!/bin/bash

# Set correct permissions and ownership for storage directory
chown -R www-data:www-data /var/www/storage
chmod -R 775 /var/www/storage

# important laravel commands
/usr/local/etc/php /var/www/artisan config:cache
/usr/local/etc/php /var/www/artisan route:cache
/usr/local/etc/php /var/www/artisan view:cache
/usr/local/etc/php /var/www/artisan storage:link
/usr/local/etc/php /var/www/artisan migrate --force


service nginx start
service supervisor start

php-fpm -F
