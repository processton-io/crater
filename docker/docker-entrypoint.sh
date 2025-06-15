#!/bin/bash

service nginx start
service supervisor start

php-fpm -F
