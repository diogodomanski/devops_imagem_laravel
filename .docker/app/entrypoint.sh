#!/bin/bash

# Wait until DB is up and running
dockerize -template ./.docker/app/.env:.env -wait tcp://app_db:3306 -timeout 40s

cd /var/www

# Install project dependencies
composer install

## Run start scripts for laravel
php artisan key:generate
php artisan config:cache
php artisan migrate

# Start php-fpm
php-fpm
