# syntax=docker/dockerfile:1
FROM php-base AS builder

ARG FRANKENPHP_VERSION='dev'

COPY --from=golang-base /usr/local/go/bin/go /usr/local/bin/go
COPY --from=golang-base /usr/local/go /usr/local/go

RUN apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
		argon2-dev \
		coreutils \
		curl-dev \
		gnu-libiconv-dev \
		libsodium-dev \
		libxml2-dev \
		linux-headers \
		oniguruma-dev \
		openssl-dev \
		readline-dev \
		sqlite-dev

WORKDIR /go/src/app

COPY go.mod go.sum ./
RUN go mod graph | awk '{if ($1 !~ "@") print $2}' | xargs go get

RUN mkdir caddy && cd caddy
COPY caddy/go.mod caddy/go.sum ./caddy/

RUN cd caddy && go mod graph | awk '{if ($1 !~ "@") print $2}' | xargs go get

COPY *.* ./
COPY caddy caddy
COPY C-Thread-Pool C-Thread-Pool
COPY internal internal
COPY testdata testdata

# todo: automate this?
# see https://github.com/docker-library/php/blob/master/8.2/bookworm/zts/Dockerfile#L57-L59 for php values
ENV CGO_LDFLAGS="-lssl -lcrypto -lreadline -largon2 -lcurl -lonig -lz $PHP_LDFLAGS" CGO_CFLAGS=$PHP_CFLAGS CGO_CPPFLAGS=$PHP_CPPFLAGS

RUN cd caddy/frankenphp && \
    go build -ldflags "-X 'github.com/caddyserver/caddy/v2.CustomVersion=FrankenPHP $FRANKENPHP_VERSION Caddy'" && \
    cp frankenphp /usr/local/bin && \
    cp /go/src/app/caddy/frankenphp/Caddyfile /etc/Caddyfile

ENTRYPOINT ["/bin/sh","-c"]

FROM php-base AS runner

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

WORKDIR /app

RUN mkdir -p /app/public
RUN echo '<?php phpinfo();' > /app/public/index.php

COPY --from=builder /usr/local/bin/frankenphp /usr/local/bin/frankenphp
COPY --from=builder /etc/Caddyfile /etc/Caddyfile

COPY --from=php-base /usr/local/include/php/ /usr/local/include/php
COPY --from=php-base /usr/local/lib/libphp.* /usr/local/lib
COPY --from=php-base /usr/local/lib/php/ /usr/local/lib/php
COPY --from=php-base /usr/local/php/ /usr/local/php
COPY --from=php-base /usr/local/bin/ /usr/local/bin
COPY --from=php-base /usr/src /usr/src

RUN sed -i 's/php/frankenphp run/g' /usr/local/bin/docker-php-entrypoint

CMD [ "--config", "/etc/Caddyfile" ]
