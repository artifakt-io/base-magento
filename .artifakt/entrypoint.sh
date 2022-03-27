#!/bin/bash
set -e

echo "syncing custom configuration for varnish/nginx"
cp -r /.artifakt/etc/varnish/* /conf/varnish || true
ls -la /conf/varnish
cp -r /.artifakt/etc/nginx/* /conf/nginxfpm || true
ls -la /conf/nginxfpm

echo DEBUG before ...
ls -la /data/pub

persistent_folder=pub
mkdir -p /data/$persistent_folder /data/setup
cp -ur /var/www/html/$persistent_folder/* /data/$persistent_folder || true  
cp -ur /var/www/html/setup/* /data/setup || true  
chown -R www-data:www-data /data/$persistent_folder /data/setup 

echo DEBUG after ...
ls -la /data/pub

# Check if Magento is installed
tableCount=$(mysql -h $ARTIFAKT_MYSQL_HOST -u $ARTIFAKT_MYSQL_USER -p$ARTIFAKT_MYSQL_PASSWORD $ARTIFAKT_MYSQL_DATABASE_NAME -B -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$ARTIFAKT_MYSQL_DATABASE_NAME';" | grep -v "count");
if [ $tableCount -gt 0 ]
then
  # Manage env.php
  if [ -f "app/etc/env.php.${ARTIFAKT_ENVIRONMENT_NAME}" ]
  then
      mv "app/etc/env.php.${ARTIFAKT_ENVIRONMENT_NAME}" app/etc/env.php
  else
      if [ -f "app/etc/env.php.sample" ]
      then
        mv app/etc/env.php.sample app/etc/env.php
      else
        echo INFO cannot find app/etc/env.php.sample, skipping 
      fi
  fi

  echo NOTICE content of "etc" folder:
  ls -la app/etc/

  # Update database and/or configuration if changes
  if [ $ARTIFAKT_IS_MAIN_INSTANCE == 1 ]
  then
    # temporary disable error
    set +e
    bin/magento setup:db:status
    dbStatus=$?
    bin/magento app:config:status
    configStatus=$?
    set -e

    echo DEBUG dbStatus=$dbStatus configStatus=$configStatus

    #1 - Put 'current/live' release under maintenance if needed
    if [[ $dbStatus == 2 || $configStatus == 2 ]]
    then
        php bin/magento maintenance:enable
    fi

    #2 - Upgrade database if needed
    if [ $dbStatus == 2 ]
    then
        php bin/magento setup:db-schema:upgrade --no-interaction
        php bin/magento setup:db-data:upgrade --no-interaction
    fi

    #3 - Upgrade configuration if needed
    #if [ $configStatus == 2 ]
    #then
    #    php bin/magento app:config:import --no-interaction
    #fi

    if [ "$(bin/magento app:config:status)" != "Config files are up to date." ]
    then
        php bin/magento app:config:import --no-interaction
        echo "Configuration is now up to date.";
    else
        echo "Configuration is already up to date.";
    fi

    #4 - Disable maintenance if needed
    if [[ $dbStatus == 2 || $configStatus == 2 ]]
    then
        php bin/magento maintenance:disable
    fi
  else
    # Wait until database and configuration are up to date
    until bin/magento setup:db:status && bin/magento app:config:status
    do
        sleep 10
    done
  fi
fi
