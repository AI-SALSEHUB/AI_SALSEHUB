#!/bin/sh
set -e
# Le volume storage est monte au runtime : on garantit les dossiers et les droits
mkdir -p storage/app/public storage/framework/cache storage/framework/sessions \
         storage/framework/views storage/logs bootstrap/cache
chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true
exec "$@"
