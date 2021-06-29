#!/bin/bash
set -e

# Manage Env.php
tableCount=$(mysql -h $ARTIFAKT_MYSQL_HOST -u $ARTIFAKT_MYSQL_USER -p$ARTIFAKT_MYSQL_PASSWORD $ARTIFAKT_MYSQL_DATABASE_NAME -B -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$ARTIFAKT_MYSQL_DATABASE_NAME';" | grep -v "count");
if [ "$tableCount" -gt "0" ]
then
  if [ -f /var/www/html/app/etc/env.php.$ARTIFAKT_ENVIRONMENT_NAME ]
  then
      mv /var/www/html/app/etc/env.php.$ARTIFAKT_ENVIRONMENT_NAME /var/html/app/etc/env.php
  else
      mv /var/www/html/app/etc/env.php.sample /var/www/html/app/etc/env.php
  fi
fi

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

# Update Magento  
if [ "$ARTIFAKT_IS_MAIN_INSTANCE" == "1" ]
then
  if [ "$(bin/magento setup:db:status)" != "All modules are up to date." ]
  then
      #1 - Put 'current/live' release under maintenance
      php bin/magento maintenance:enable

      #2 - Upgrade Database
      php bin/magento setup:db-schema:upgrade --no-interaction
      php bin/magento setup:db-data:upgrade --no-interaction
      php bin/magento app:config:import --no-interaction

      #3 - Disable Maintenance
      php bin/magento maintenance:disable
      echo "Database is now up to date."
  else
    echo "Database is already up to date."
  fi
else
  # Wait until database is up to date
  until [ "$(bin/magento setup:db:status)" == "All modules are up to date." ]
  do sleep 10 && echo "Database is not up to date, waiting ..."
  done
  echo "Database is up to date."
fi
