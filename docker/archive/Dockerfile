FROM php:8.1-cli-alpine

WORKDIR /app

COPY ./docker/archive/15min/* /etc/periodic/15min/
COPY ./docker/archive/hourly/* /etc/periodic/hourly/
COPY ./docker/archive/daily/* /etc/periodic/daily/

ENV PHP_MEMORY_LIMIT=256M

RUN set -ex \
 && apk add --update --no-cache \
    bash \
    tini \
 && rm -rf /var/cache/apk/* \
 && docker-php-ext-install -j "$(nproc)" \
    mysqli \
    pdo_mysql \
 && chmod a+x /etc/periodic/15min/* \
 && chmod a+x /etc/periodic/hourly/* \
 && chmod a+x /etc/periodic/daily/*

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["/usr/sbin/crond", "-f"]
