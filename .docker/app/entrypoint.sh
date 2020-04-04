#!/bin/bash

cd /var/www

# Install project dependencies
composer install

## Run start scripts for laravel
php artisan key:generate
php artisan migrate

# Start php-fpm
php-fpm
