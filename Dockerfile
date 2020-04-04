FROM php:7.4-fpm-alpine

RUN apk add bash mysql-client
RUN docker-php-ext-install pdo pdo_mysql

WORKDIR /var/www
RUN rm -rf /var/www/html

COPY . .

RUN ./.docker/app/prepare-env.sh

RUN ln -s public html

EXPOSE 9000

ENTRYPOINT ["./.docker/app/run.sh"]
