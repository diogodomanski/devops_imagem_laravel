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

Criar o script `.docker/app/prepare-env.sh` para preparar o ambiente do laravel

```
#!/bin/bash

cd /var/www

# Check if .env file does not exit
if [ ! -f ".env" ]; then
    # Create .env file based on .env.example
    cp .env.example .env
    chown 1000:1000 .env

    # SET DB_HOST value to app_db
    sed -i -E 's/^(DB_HOST[[:blank:]]*=[[:blank:]]*).*/\1app_db/' .env

    # SET DB_PASSWORD value to root
    sed -i -E 's/^(DB_PASSWORD[[:blank:]]*=[[:blank:]]*).*/\1root/' .env

    # SET REDIS_HOST value to app_redis
    sed -i -E 's/^(REDIS_HOST[[:blank:]]*=[[:blank:]]*).*/\1app_redis/' .env
fi

# Install composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install project dependencies
composer install

## Run start scripts for laravel
php artisan key:generate
php artisan config:cache
```

Adicionar permissão de execução ao arquivo `.docker/app/prepare-env.sh`

```
$ chmod +x .docer/app/prepare-env.sh
```

Criar o script para entrypoint do `app` em `.docker/app/entrypoint.sh`

```
#!/bin/bash

# Wait until DB is up and running
dockerize -wait tcp://app_db:3306 -timeout 40s

cd /var/www

php artisan migrate
php-fpm
```

Criar arquivo `Dockerfile` na raiz do projeto e colocar o seguinte conteúdo

```
FROM php:7.4-fpm-alpine

RUN apk add --no-cache openssl bash mysql-client
RUN docker-php-ext-install pdo pdo_mysql

ENV DOCKERIZE_VERSION v0.6.1
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz

WORKDIR /var/www
RUN rm -rf /var/www/html

COPY . .

RUN ./.docker/app/prepare-env.sh

RUN ln -s public html

EXPOSE 9000

ENTRYPOINT ["./.docker/app/entrypoint.sh"]
```

### Passo 2: Criando container Nginx
---
Criar o arquivo `.docker/nginx/nginx.conf` com as configurações do nginx para rodar com o `php-fpm`

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
        # entrypoint: dockerize -wait tcp://app_db:3306 -timeout 40s ./.docker/app/entrypoint.sh
        volumes:
            - .:/var/www
        networks:
            - app-network
        depends_on:
            - db
            - redis

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
        depends_on:
          - app

    db:
        image: mysql
        container_name: app_db
        command: --default-authentication-plugin=mysql_native_password --innodb-use-native-aio=0
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
$ docker-compose up --build -d
```

Dê permissões de leitura e escrita para o usuário do nginx na pasta `./storage` e depois acesse `http://localhost:8000` no navegador.


## Comandos úteis

Sobre os containers sem executar os scripts de build

```
$ docker-compose up -d
```

Pára os containers

```
$ docker-compose down
```

## Alternativa ao dockerize

Criar o arquivo `.docker/app/wait-for-it.sh` que servirá para aguardar o BD subir antes de subir a aplicação:

```
#!/usr/bin/env bash
# Use this script to test if a given TCP host/port are available

WAITFORIT_cmdname=${0##*/}

echoerr() { if [[ $WAITFORIT_QUIET -ne 1 ]]; then echo "$@" 1>&2; fi }

usage()
{
    cat << USAGE >&2
Usage:
    $WAITFORIT_cmdname host:port [-s] [-t timeout] [-- command args]
    -h HOST | --host=HOST       Host or IP under test
    -p PORT | --port=PORT       TCP port under test
                                Alternatively, you specify the host and port as host:port
    -s | --strict               Only execute subcommand if the test succeeds
    -q | --quiet                Don't output any status messages
    -t TIMEOUT | --timeout=TIMEOUT
                                Timeout in seconds, zero for no timeout
    -- COMMAND ARGS             Execute command with args after the test finishes
USAGE
    exit 1
}

wait_for()
{
    if [[ $WAITFORIT_TIMEOUT -gt 0 ]]; then
        echoerr "$WAITFORIT_cmdname: waiting $WAITFORIT_TIMEOUT seconds for $WAITFORIT_HOST:$WAITFORIT_PORT"
    else
        echoerr "$WAITFORIT_cmdname: waiting for $WAITFORIT_HOST:$WAITFORIT_PORT without a timeout"
    fi
    WAITFORIT_start_ts=$(date +%s)
    while :
    do
        if [[ $WAITFORIT_ISBUSY -eq 1 ]]; then
            nc -z $WAITFORIT_HOST $WAITFORIT_PORT
            WAITFORIT_result=$?
        else
            (echo > /dev/tcp/$WAITFORIT_HOST/$WAITFORIT_PORT) >/dev/null 2>&1
            WAITFORIT_result=$?
        fi
        if [[ $WAITFORIT_result -eq 0 ]]; then
            WAITFORIT_end_ts=$(date +%s)
            echoerr "$WAITFORIT_cmdname: $WAITFORIT_HOST:$WAITFORIT_PORT is available after $((WAITFORIT_end_ts - WAITFORIT_start_ts)) seconds"
            break
        fi
        sleep 1
    done
    return $WAITFORIT_result
}

wait_for_wrapper()
{
    # In order to support SIGINT during timeout: http://unix.stackexchange.com/a/57692
    if [[ $WAITFORIT_QUIET -eq 1 ]]; then
        timeout $WAITFORIT_BUSYTIMEFLAG $WAITFORIT_TIMEOUT $0 --quiet --child --host=$WAITFORIT_HOST --port=$WAITFORIT_PORT --timeout=$WAITFORIT_TIMEOUT &
    else
        timeout $WAITFORIT_BUSYTIMEFLAG $WAITFORIT_TIMEOUT $0 --child --host=$WAITFORIT_HOST --port=$WAITFORIT_PORT --timeout=$WAITFORIT_TIMEOUT &
    fi
    WAITFORIT_PID=$!
    trap "kill -INT -$WAITFORIT_PID" INT
    wait $WAITFORIT_PID
    WAITFORIT_RESULT=$?
    if [[ $WAITFORIT_RESULT -ne 0 ]]; then
        echoerr "$WAITFORIT_cmdname: timeout occurred after waiting $WAITFORIT_TIMEOUT seconds for $WAITFORIT_HOST:$WAITFORIT_PORT"
    fi
    return $WAITFORIT_RESULT
}

# process arguments
while [[ $# -gt 0 ]]
do
    case "$1" in
        *:* )
        WAITFORIT_hostport=(${1//:/ })
        WAITFORIT_HOST=${WAITFORIT_hostport[0]}
        WAITFORIT_PORT=${WAITFORIT_hostport[1]}
        shift 1
        ;;
        --child)
        WAITFORIT_CHILD=1
        shift 1
        ;;
        -q | --quiet)
        WAITFORIT_QUIET=1
        shift 1
        ;;
        -s | --strict)
        WAITFORIT_STRICT=1
        shift 1
        ;;
        -h)
        WAITFORIT_HOST="$2"
        if [[ $WAITFORIT_HOST == "" ]]; then break; fi
        shift 2
        ;;
        --host=*)
        WAITFORIT_HOST="${1#*=}"
        shift 1
        ;;
        -p)
        WAITFORIT_PORT="$2"
        if [[ $WAITFORIT_PORT == "" ]]; then break; fi
        shift 2
        ;;
        --port=*)
        WAITFORIT_PORT="${1#*=}"
        shift 1
        ;;
        -t)
        WAITFORIT_TIMEOUT="$2"
        if [[ $WAITFORIT_TIMEOUT == "" ]]; then break; fi
        shift 2
        ;;
        --timeout=*)
        WAITFORIT_TIMEOUT="${1#*=}"
        shift 1
        ;;
        --)
        shift
        WAITFORIT_CLI=("$@")
        break
        ;;
        --help)
        usage
        ;;
        *)
        echoerr "Unknown argument: $1"
        usage
        ;;
    esac
done

if [[ "$WAITFORIT_HOST" == "" || "$WAITFORIT_PORT" == "" ]]; then
    echoerr "Error: you need to provide a host and port to test."
    usage
fi

WAITFORIT_TIMEOUT=${WAITFORIT_TIMEOUT:-15}
WAITFORIT_STRICT=${WAITFORIT_STRICT:-0}
WAITFORIT_CHILD=${WAITFORIT_CHILD:-0}
WAITFORIT_QUIET=${WAITFORIT_QUIET:-0}

# Check to see if timeout is from busybox?
WAITFORIT_TIMEOUT_PATH=$(type -p timeout)
WAITFORIT_TIMEOUT_PATH=$(realpath $WAITFORIT_TIMEOUT_PATH 2>/dev/null || readlink -f $WAITFORIT_TIMEOUT_PATH)

WAITFORIT_BUSYTIMEFLAG=""
if [[ $WAITFORIT_TIMEOUT_PATH =~ "busybox" ]]; then
    WAITFORIT_ISBUSY=1
    # Check if busybox timeout uses -t flag
    # (recent Alpine versions don't support -t anymore)
    if timeout &>/dev/stdout | grep -q -e '-t '; then
        WAITFORIT_BUSYTIMEFLAG="-t"
    fi
else
    WAITFORIT_ISBUSY=0
fi

if [[ $WAITFORIT_CHILD -gt 0 ]]; then
    wait_for
    WAITFORIT_RESULT=$?
    exit $WAITFORIT_RESULT
else
    if [[ $WAITFORIT_TIMEOUT -gt 0 ]]; then
        wait_for_wrapper
        WAITFORIT_RESULT=$?
    else
        wait_for
        WAITFORIT_RESULT=$?
    fi
fi

if [[ $WAITFORIT_CLI != "" ]]; then
    if [[ $WAITFORIT_RESULT -ne 0 && $WAITFORIT_STRICT -eq 1 ]]; then
        echoerr "$WAITFORIT_cmdname: strict mode, refusing to execute subprocess"
        exit $WAITFORIT_RESULT
    fi
    exec "${WAITFORIT_CLI[@]}"
else
    exit $WAITFORIT_RESULT
fi
```

Adicionar permissão de execução ao arquivo `.docker/app/wait-for-it.sh`

```
$ chmod +x .docer/app/wait-for-it.sh
```

Substituir o conteúdo do script `.docker/app/entrypoint.sh`

```
#!/bin/bash

cd /var/www

./.docker/app/wait-for-it.sh -q app_db:3306 -- php artisan migrate && php-fpm
```
