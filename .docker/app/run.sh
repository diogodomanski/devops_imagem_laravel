#!/bin/bash

cd /var/www

./.docker/app/wait-for-it.sh -q app_db:3306 -- php artisan migrate && php-fpm
