FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    build-essential \
    g++ \
    gosu \
    apache2 \
    php \
    libapache2-mod-php \
    php-mysql \
    unzip \
    lua5.1 \
    liblua5.1-0-dev \
    lua-socket \
    luarocks \
    git \
    mariadb-client \
    libmariadb-dev \
    gettext-base \
    && luarocks install luafilesystem \
    && a2enmod cgi rewrite \
    && sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf \
    && sed -i 's/memory_limit = .*/memory_limit = 512M/g' /etc/php/*/apache2/php.ini \
    && sed -i 's/upload_max_filesize = .*/upload_max_filesize = 250M/g' /etc/php/*/apache2/php.ini \
    && sed -i 's/post_max_size = .*/post_max_size = 250M/g' /etc/php/*/apache2/php.ini \
    && ln -sf /usr/lib/x86_64-linux-gnu/liblua5.1.so.0 /usr/lib/x86_64-linux-gnu/liblua5.1.so || true \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

COPY templates /templates
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /opt/conquest
ENTRYPOINT ["/entrypoint.sh"]
