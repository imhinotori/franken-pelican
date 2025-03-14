ARG PHP_VERSION=8.3
ARG USER=www-data

##############################
# Etapa 1: Builder - FrankenPHP
##############################
FROM dunglas/frankenphp:latest-builder-php${PHP_VERSION} AS builder

# Copiar xcaddy desde la imagen de Caddy builder
COPY --from=caddy:builder /usr/bin/xcaddy /usr/bin/xcaddy

# Habilitar CGO y configurar flags de compilación
ENV CGO_ENABLED=1 \
    XCADDY_SETCAP=1 \
    XCADDY_GO_BUILD_FLAGS='-ldflags="-w -s" -trimpath'

# Compilar FrankenPHP con módulos básicos
RUN xcaddy build \
    --output /usr/local/bin/frankenphp \
    --with github.com/dunglas/frankenphp=./ \
    --with github.com/dunglas/frankenphp/caddy=./caddy/ \
    --with github.com/dunglas/caddy-cbrotli

##############################
# Etapa 2: Imagen final - Pelican Panel
##############################
FROM dunglas/frankenphp:latest-php${PHP_VERSION} AS base

LABEL org.opencontainers.image.title="Pelican Panel with FrankenPHP"
LABEL org.opencontainers.image.description="Contenedor optimizado para ejecutar Pelican Panel con FrankenPHP."
LABEL org.opencontainers.image.source="https://github.com/pelican-dev/panel"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="Pelican Dev"

# Copiar el binario compilado de FrankenPHP
COPY --from=builder /usr/local/bin/frankenphp /usr/local/bin/frankenphp

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tar \
    unzip \
    git \
    libonig-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libzip-dev \
    libsqlite3-dev && rm -rf /var/lib/apt/lists/*

# Instalar extensiones PHP necesarias
RUN install-php-extensions gd mbstring bcmath xml curl zip intl sqlite3 mysqli pdo_mysql

# Instalar Composer globalmente
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Crear directorio para Pelican Panel y establecer directorio de trabajo
WORKDIR /var/www/pelican

# Descargar y extraer Pelican Panel
RUN mkdir -p /var/www/pelican && \
    curl -L https://github.com/pelican-dev/panel/releases/latest/download/panel.tar.gz | tar -xzv -C /var/www/pelican

# Instalar dependencias de Composer (sin entorno de desarrollo y optimizando el autoloader)
RUN composer install --no-dev --optimize-autoloader

# Ajustar que la variable de entorno USER esté definida en tiempo de ejecución
ENV USER=${USER}

# Copiar archivo de configuración de Caddy (asegúrate de que "Caddyfile" exista en el contexto de compilación)
COPY Caddyfile /etc/caddy/Caddyfile

# Copiar el script de entrypoint personalizado
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Permitir que FrankenPHP se vincule a puertos bajos (80 y 443)
RUN setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/frankenphp

# Cambiar a usuario no privilegiado
USER ${USER}

# Definir el entrypoint personalizado y el comando de inicio.
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
