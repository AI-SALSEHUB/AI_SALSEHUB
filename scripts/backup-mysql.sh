#!/bin/bash
# Sauvegarde quotidienne MySQL (VPS OVH). Cron : 0 2 * * * /opt/saleshub/backup-mysql.sh
set -e
cd /opt/saleshub
set -a; . ./.env; set +a
mkdir -p backup
F=backup/saleshub_$(date +%Y%m%d_%H%M%S).sql.gz
docker compose -f docker-compose.prod.yml exec -T mysql \
  mysqldump -uroot -p"$DB_ROOT_PASSWORD" --single-transaction --quick --no-tablespaces "$DB_DATABASE" | gzip > "$F"
[ -s "$F" ] || { rm -f "$F"; echo "backup vide" >&2; exit 1; }
find backup -name 'saleshub_*.sql.gz' -mtime +7 -delete
