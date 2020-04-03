FROM php:7.4-fpm-alpine

RUN apk add bash mysql-client
RUN docker-php-ext-install pdo pdo_mysql

WORKDIR /var/www
RUN rm -rf /var/www/html

COPY . .

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

RUN composer install && \
    php artisan key:generate && \
    php artisan config:cache

RUN ln -s public html

EXPOSE 9000

ENTRYPOINT ["./.docker/app/run.sh"]
