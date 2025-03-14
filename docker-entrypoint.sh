#!/bin/sh
set -e

# Verifica si el archivo .env existe; si no, ejecuta la configuración inicial.
if [ ! -f /var/www/pelican/.env ]; then
    echo ".env no encontrado. Ejecutando configuración inicial..."
    php artisan p:environment:setup --no-interaction
fi

# Ajusta permisos en los directorios clave.
chmod -R 755 storage/* bootstrap/cache/
chown -R ${USER}:${USER} /var/www/pelican

# Ejecuta el comando que se le pase al contenedor.
exec "$@"
