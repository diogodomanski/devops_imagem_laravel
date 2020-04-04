#!/bin/bash

cd /var/www

# Check if .env file does not exit
if [ ! -f ".env" ]; then
    # Create .env file based on .env.example
    cp .env.example .env
    chown 1000:1000 .env

    # SET DB_HOST value
    sed -i -E 's/^(DB_HOST[[:blank:]]*=[[:blank:]]*).*/\1app_db/' .env

    # SET DB_PASSWORD value
    sed -i -E 's/^(DB_PASSWORD[[:blank:]]*=[[:blank:]]*).*/\1root/' .env

    # SET REDIS_HOST value
    sed -i -E 's/^(REDIS_HOST[[:blank:]]*=[[:blank:]]*).*/\1app_redis/' .env
fi

# Install composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install project dependencies
composer install

## Run start scripts for laravel
php artisan key:generate
php artisan config:cache
