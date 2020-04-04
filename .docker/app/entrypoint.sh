#!/bin/bash

## Run start scripts for laravel
php artisan migrate

# Start php-fpm
php-fpm
