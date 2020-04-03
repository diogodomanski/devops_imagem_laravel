#!/bin/bash

cd /var/www

./.docker/app/prepare_env.sh

php artisan migrate
php-fpm
