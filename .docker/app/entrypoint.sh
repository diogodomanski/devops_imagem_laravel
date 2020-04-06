#!/bin/bash

composer install \
    && php artisan key:generate \
    && php artisan cache:clear \
    && chmod -R 775 storage \
    && npm install

## Run start scripts for laravel
php artisan migrate

# Start php-fpm
php-fpm
