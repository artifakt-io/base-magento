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

  # Update database and/or configuration if changes
  if [ "$ARTIFAKT_IS_MAIN_INSTANCE" == "1" ]
  then
    #1 - Put 'current/live' release under maintenance if needed
    if [[ "$(bin/magento setup:db:status)" != "All modules are up to date." || "$(bin/magento app:config:status)" != "Config files are up to date." ]]
    then
        php bin/magento maintenance:enable
    fi

    #2 - Upgrade database if needed
    if [ "$(bin/magento setup:db:status)" != "All modules are up to date." ]
    then
        php bin/magento setup:db-schema:upgrade --no-interaction
        php bin/magento setup:db-data:upgrade --no-interaction
    else
      echo "Database is already up to date."
    fi

    #3 - Upgrade configuration if needed
    if [ "$(bin/magento app:config:status)" != "Config files are up to date." ]
    then
        php bin/magento app:config:import --no-interaction
    else
      echo "Configuration is already up to date."
    fi

    #4 - Disable maintenance if needed
    maintenanceStatusMsg=$(bin/magento maintenance:status)
    maintenanceOnSubstring="Status: maintenance mode is active"
    if [ "${maintenanceStatusMsg/$maintenanceOnSubstring}" != "$maintenanceStatusMsg" ]
    then
        php bin/magento maintenance:disable
    fi
  else
    # Wait until database and configuration are up to date
    until [[ "$(bin/magento setup:db:status)" == "All modules are up to date." && "$(bin/magento app:config:status)" == "Config files are up to date." ]]
    do sleep 10 && echo "Database and/or configuration is/are not up to date, waiting ..."
    done
    echo "Database and configuration are up to date."
  fi
fi
