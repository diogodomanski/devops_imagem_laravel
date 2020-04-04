#!/bin/bash

# Wait until DB is up and running
dockerize -wait tcp://app_db:3306 -timeout 40s

cd /var/www

php artisan migrate
php-fpm
