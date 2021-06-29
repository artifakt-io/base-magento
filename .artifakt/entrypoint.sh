#!/bin/bash
set -e

# Manage env.php
tableCount=$(mysql -h $ARTIFAKT_MYSQL_HOST -u $ARTIFAKT_MYSQL_USER -p$ARTIFAKT_MYSQL_PASSWORD $ARTIFAKT_MYSQL_DATABASE_NAME -B -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$ARTIFAKT_MYSQL_DATABASE_NAME';" | grep -v "count");


# Mount pub/media directory
rm -rf /var/www/html/pub/media && \
  mkdir -p /data/pub/media && \
  ln -sfn /data/pub/media /var/www/html/pub/media && \
  chown -h www-data:www-data /var/www/html/pub/media /data/pub/media

# Mount pub/static/_cache directory
rm -rf /var/www/html/pub/static/_cache && \
  mkdir -p /data/pub/static/_cache && \
  ln -sfn /data/pub/static/_cache /var/www/html/pub/static/_cache && \
  chown -h www-data:www-data /var/www/html/pub/static/_cache /data/pub/static/_cache
  
# Mount var directory
mkdir -p /data/var && \
  mv -f /var/www/html/var/.htaccess /data/var/ && \
  rm -rf /var/www/html/var && \
  ln -sfn /data/var /var/www/html/var && \
  chown -h www-data:www-data /var/www/html/var /data/var

