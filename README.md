# DevOps > Projeto Prático > Publicando imagem Laravel

## Descrição
Criar um container Docker com uma aplicação Laravel usando:
* Laravel
* PHP-FPM
* Nginx
* MySQL
* Redis

## Resultado

A url para a imagem do `app` no Dockerhub é

https://hub.docker.com/repository/docker/diogodomanski/imagem-laravel

Observações:
* Foi usado PHP-FPM 7.4
* Foi usado MySQL 8
* Foi usado Nginx 1.17
* Foi usado Redis 5.0
* No Dockerfile do `app` estão sendo executados o `key:generate` e o `config:cache` do laravel
* Foi criado um script para ser o `ENTRYPOINT` do `app` (pra rodar as migrations e subir o php-fpm)


## Processo de resolução da atividade

### Passo 1: Criando app Laravel
---
Instalar o composer

```
$ sudo apt install composer
```

Criar o projeto laravel

```
$ cd /caminho/para/a/pasta/de/projetos
$ composer create-project --prefer-dist laravel/laravel <nome_do_projeto>
$ cd <nome_do_projeto>
```

Configurar conexão com o MySQL no arquivo `.env`

```
DB_CONNECTION=mysql
DB_HOST=app_db
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=root
DB_PASSWORD=root
```

Configurar conexão com o Redis no arquivo `.env`

```
REDIS_HOST=app_redis
REDIS_PASSWORD=null
REDIS_PORT=6379
```

Criar o script para entrypoint do app em .docker/app/run.sh

```
#!/bin/bash

cd /var/www
php artisan migrate
php-fpm
```

Criar arquivo `Dockerfile` na raiz do projeto e colocar o seguinte conteúdo

```
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
```

### Passo 2: Criando container Nginx
---
Criar o arquivo `.docker/nginx/nginx.conf` com as configurações do nginx para rodar com o php-fpm

```
server {
    listen 80;
    index index.php index.html;
    root /var/www/public;

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass app:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }

    location / {
        try_files $uri $uri/ /index.php$query_string;
        gzip_static on;
    }
}
```

Criar arquivo `.docker/nginx/Dockerfile`

```
FROM nginx:1.17-alpine

RUN rm /etc/nginx/conf.d/default.conf
COPY ./nginx.conf /etc/nginx/conf.d
```

### Passo 3: Criando o docker-composer
---
Criar arquivo `docker-compose.yaml`

```
version: '3'

services:

    app:
        build: .
        container_name: app
        volumes:
            - .:/var/www
        networks:
            - app-network
        depends_on:
            - db

    nginx:
        build: .docker/nginx
        container_name: app_nginx
        restart: always
        tty: true
        ports:
            - "8000:80"
        volumes:
            - .:/var/www
        networks:
            - app-network

    db:
        image: mysql
        container_name: app_db
        command: --default-authentication-plugin=mysql_native_password
        restart: always
        tty: true
        ports:
            - "33006:3306"
        volumes:
            - ./.docker/dbdata:/var/lib/mysql
        environment:
            - MYSQL_DATABASE=laravel
            - MYSQL_ROOT_PASSWORD=root
            - MYSQL_USER=root
        networks:
            - app-network
    
    redis:
        image: redis:alpine
        container_name: app_redis
        expose:
            - 6379
        networks:
            - app-network

networks:
    app-network:
        driver: bridge
```

### Passo 4: Rodando com o docker-compose
---
```
$ docker-compose up -d
```

Dê permissões de leitura e escrita para o usuário do nginx na pasta `./storage` e depois acesse `http://localhost:8000` no navegador.


### Comandos úteis

```
$ docker-compose build --force-rm --no-cache
```

```
$ docker-compose down
```
