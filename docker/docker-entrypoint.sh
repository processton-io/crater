#!/bin/bash

service cron start
service nginx start
service php8.3-fpm start
service supervisor start

# exec "$@"