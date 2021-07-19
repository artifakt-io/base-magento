#!/bin/bash
set -e

# Check if Magento is installed
tableCount=$(mysql -h $ARTIFAKT_MYSQL_HOST -u $ARTIFAKT_MYSQL_USER -p$ARTIFAKT_MYSQL_PASSWORD $ARTIFAKT_MYSQL_DATABASE_NAME -B -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$ARTIFAKT_MYSQL_DATABASE_NAME';" | grep -v "count");
if [ "$tableCount" -gt "0" ]
then
  # Manage env.php
  if [ -f "app/etc/env.php.${ARTIFAKT_ENVIRONMENT_NAME}" ]
  then
      mv "app/etc/env.php.${ARTIFAKT_ENVIRONMENT_NAME}" app/etc/env.php
  else
      mv app/etc/env.php.sample app/etc/env.php
  fi

  # Update config if changes
  php bin/magento app:config:import --no-interaction

  # Update database if changes
  if [ "$ARTIFAKT_IS_MAIN_INSTANCE" == "1" ]
  then
    if [ "$(bin/magento setup:db:status)" != "All modules are up to date." ]
    then
        #1 - Put 'current/live' release under maintenance
        php bin/magento maintenance:enable

        #2 - Upgrade database
        php bin/magento setup:db-schema:upgrade --no-interaction
        php bin/magento setup:db-data:upgrade --no-interaction
        php bin/magento app:config:import --no-interaction

        #3 - Disable maintenance
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
fi
