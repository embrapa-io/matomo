#!/bin/bash

set -ex

SCRIPT_DIR=$(dirname "$0")

cd "$SCRIPT_DIR"

pwd

docker compose exec archive /usr/local/bin/php /app/console core:archive --url=https://hit.embrapa.io

docker compose exec matomo chown -R www-data:www-data /var/www/html

# Insert a file in /etc/cron.daily/matomo with:

# #!/bin/sh
# find /var/log -type f -name "matomo-archive-*" -mtime +14 -exec rm {} \;
# DATE="$(date +%Y-%m-%d)"
# /root/matomo/archive.sh >> /var/log/matomo-archive-$DATE.log 2>&1
