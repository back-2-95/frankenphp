# syntax=docker/dockerfile:1
FROM golang:1.20

ENV CFLAGS="-ggdb3"
ENV PHPIZE_DEPS \
    autoconf \
    dpkg-dev \
    file \
    g++ \
    gcc \
    libc-dev \
    make \
    pkg-config \
    re2c

RUN apt-get update && \
    apt-get -y --no-install-recommends install \
    $PHPIZE_DEPS \
    libargon2-dev \
    libcurl4-openssl-dev \
    libonig-dev \
    libreadline-dev \
    libsodium-dev \
    libsqlite3-dev \
    libssl-dev \
    libxml2-dev \
    zlib1g-dev \
    bison \
    libnss3-tools \
    # Dev tools \
    git \
    clang \
    llvm \
    gdb \
    valgrind \
    neovim \
    zsh \
    libtool-bin && \
    echo 'set auto-load safe-path /' > /root/.gdbinit && \
    echo '* soft core unlimited' >> /etc/security/limits.conf \
    && \
    apt-get clean 

RUN git clone --branch=PHP-8.2 https://github.com/php/php-src.git && \
    cd php-src && \
    # --enable-embed is only necessary to generate libphp.so, we don't use this SAPI directly
    ./buildconf --force && \
    ./configure \
        --enable-embed \
        --enable-zts \
        --disable-zend-signals \
        --enable-zend-max-execution-timers \
        --enable-debug && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    cp php.ini-development /usr/local/lib/php.ini && \
    echo "zend_extension=opcache.so\nopcache.enable=1" >> /usr/local/lib/php.ini &&\
    php --version

WORKDIR /go/src/app

COPY . .

RUN go get -d -v ./...

CMD [ "zsh" ]
