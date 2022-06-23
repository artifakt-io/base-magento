#!/bin/bash
set -e

#0 Sync custom configuration for Varnish and Nginx
echo "#0 - sync custom configuration files for Varnish and Nginx"
set +e
cp -r /.artifakt/etc/varnish/* /conf/varnish || true
cp -r /.artifakt/etc/nginx/* /conf/nginxfpm || true
echo "DEBUG: content of configuration folders:"
ls -la /conf/varnish
ls -la /conf/nginxfpm
set -e

## CUSTOM CONFIGURATION VARIABLES FROM CONSOLE
# ENV_MAGE_STATIC_JOBS
# ENV_MAGE_THEME
# ENV_MAGE_THEME_EXCLUDE
# ENV_MAGE_LANG
# ENV_MAGE_LANG_EXCLUDE

## PRE-DEFINED CONFIGURATION VARIABLES FROM SYSTEM
# ARTIFAKT_REPLICA_LIST
# ARTIFAKT_MYSQL_*
# ARTIFAKT_ENVIRONMENT_NAME

PERSISTENT_FOLDER_LIST=('pub/media' 'pub/static' 'var')

for persistent_folder in ${PERSISTENT_FOLDER_LIST[@]}; do

  echo "DEBUG: Init persistent folder /data/$persistent_folder"
  mkdir -p /data/$persistent_folder

  echo Copy modified/new files from container /var/www/html/$persistent_folder to volume /data/$persistent_folder
  echo "DEBUG: Copy modified/new files from container /var/www/html/$persistent_folder to volume /data/$persistent_folder"
  cp -ur /var/www/html/$persistent_folder/* /data/$persistent_folder || true

  echo "DEBUG: Link /data/$persistent_folder directory to /var/www/html/$persistent_folder"
  rm -rf /var/www/html/$persistent_folder && \
    mkdir -p /var/www/html && \
    ln -sfn /data/$persistent_folder /var/www/html/$persistent_folder
    #chown -h -R -L www-data:www-data /var/www/html/$persistent_folder /data/$persistent_folder
done

# Check if Magento is installed
tableCount=$(mysql -h $ARTIFAKT_MYSQL_HOST -u $ARTIFAKT_MYSQL_USER -p$ARTIFAKT_MYSQL_PASSWORD $ARTIFAKT_MYSQL_DATABASE_NAME -B -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$ARTIFAKT_MYSQL_DATABASE_NAME';" | grep -v "count");
if [ $tableCount -gt 0 ]
then
  # Manage env.php
  if [ -f "app/etc/env.php.${ARTIFAKT_ENVIRONMENT_NAME}" ]
  then
      mv "app/etc/env.php.${ARTIFAKT_ENVIRONMENT_NAME}" app/etc/env.php
      echo "INFO moved env. specific conf as env.php"
  else
      if [ -f "/.artifakt/app/etc/env.php.sample" ]
      then
        mv /.artifakt/app/etc/env.php.sample app/etc/env.php
      echo "INFO moved sample env. conf to env.php"
      else
        echo INFO cannot find app/etc/env.php.sample, skipping 
      fi
  fi

  # Debug configuration files
  echo "DEBUG content of etc folder"
  ls -la app/etc/ || true
  cat app/etc/env.php || true
  cat app/etc/config.php || true

  # Update database and/or configuration if changes
  if [ $ARTIFAKT_IS_MAIN_INSTANCE == 1 ]
  then
    # read db and config statuses 
    # while temporary disabling errors
    set +e
    bin/magento setup:db:status
    dbStatus=$?
    bin/magento app:config:status
    configStatus=$?
    set -e

    echo DEBUG dbStatus=$dbStatus configStatus=$configStatus

    #1 - Put 'current/live' release under maintenance if needed
    echo "#1 - Put 'current/live' release under maintenance if needed"
    if [[ $dbStatus == 2 || $configStatus == 2 ]]
    then
        php bin/magento maintenance:enable
    fi

    su www-data -s /bin/bash -c 'until composer dump-autoload --no-dev --optimize --apcu --no-interaction; do echo "composer dump-autoload failed" && sleep 1; done;'

    #3 - Upgrade configuration if needed
    echo "#3 - Upgrade configuration if needed"
    if [ "$(bin/magento app:config:status)" != "Config files are up to date." ]
    then
        php bin/magento app:config:import --no-interaction
        echo "Configuration is now up to date.";
    else
        echo "Configuration is already up to date.";
    fi

    #2 - Upgrade database if needed
    echo "#2 - Upgrade database if needed"
    if [ $dbStatus == 2 ]
    then
        php bin/magento setup:db-schema:upgrade --no-interaction
        php bin/magento setup:db-data:upgrade --no-interaction
    fi
    
    #4 - Sync with Nginx FPM container
    #    This is the longest part because of many files to check
    #    And because files are stored in EFS, not EBS
    echo "#4 - Sync pub folder with Nginx FPM container"
    persistent_folder=pub
    mkdir -p /data/$persistent_folder /data/setup
    cp -pur /var/www/html/$persistent_folder/* /data/$persistent_folder || true  
    cp -pur /var/www/html/setup/* /data/setup || true  
    
    #6 - remove generated content and rebuild page generation
    echo "#6 - Remove generated content and rebuild page generation"
    set +e
    rm -rf var/{cache,di,generation,page_cache,view_preprocessed}
    su www-data -s /bin/bash -c 'until composer dump-autoload --no-dev --optimize --apcu --no-interaction; do echo "ERROR: composer dump-autoload failed" && sleep 1; done;'
    su www-data -s /bin/bash -c 'php bin/magento setup:di:compile' 
    su www-data -s /bin/bash -c 'until composer dump-autoload --no-dev --optimize --apcu --no-interaction; do echo "ERROR: composer dump-autoload failed" && sleep 1; done;'
    set -e

    #7 - Deploy static content with languages and themes
    # DISABLED, MOVED lower after #5
    #echo "#7 - Deploy static content with languages and themes"
    #su www-data -s /bin/bash -c "php bin/magento setup:static-content:deploy -f --no-interaction --jobs ${ARTIFAKT_MAGE_STATIC_JOBS}  --content-version=${ARTIFAKT_BUILD_ID} --theme=${ARTIFAKT_MAGE_STATIC_THEME:-all} --exclude-theme=${ARTIFAKT_MAGE_THEME_EXCLUDE:-none} --language=${ARTIFAKT_MAGE_LANG:-all} --exclude-language=${ARTIFAKT_MAGE_LANG_EXCLUDE:-none}"
    #ls -la /data/var

    #8 - Finally fix perms for web server
    #echo "#8 - Finally fix perms for web server"
    #chown -R www-data:www-data /var/log/artifakt
 
    #9 - Enable Varnish as cache backend
    echo "#9 - Enable Varnish as cache backend"
    php bin/magento config:set --scope=default --scope-code=0 system/full_page_cache/caching_application 2
    php bin/magento setup:config:set --http-cache-hosts=${ARTIFAKT_REPLICA_LIST} --no-interaction
 
    #10 - Disable maintenance if needed
    echo "#10 - Disable maintenance if needed"
    if [[ $dbStatus == 2 || $configStatus == 2 ]]
    then
        php bin/magento maintenance:disable
    fi
  else
    # Non main instances must wait until database and configuration are up to date
    until bin/magento setup:db:status && bin/magento app:config:status
    do
        sleep 10
    done
  fi # end of "Update database and/or configuration if changes"
  
  #5 - Optional: disable 2FA module
  echo "#5 - Disable 2FA module if available"
  if php bin/magento module:status | grep -q 'TwoFactorAuth'; then
    set +e
    su www-data -s /bin/bash -c 'until php bin/magento module:disable Magento_TwoFactorAuth --clear-static-content; do echo "ERROR: module:disable failed"; composer dump-autoload --no-dev --optimize --apcu --no-interaction; sleep 1; done;'
    echo "DEBUG: list of enabled modules"
    su www-data -s /bin/bash -c 'php bin/magento module:status'
    su www-data -s /bin/bash -c 'until php bin/magento setup:di:compile; do echo "ERROR: di:compile failed"; composer dump-autoload --no-dev --optimize --apcu --no-interaction; sleep 1; done;'
    set -e
  fi  
  
  #7 - Deploy static content with languages and themes
  echo "#7 - Deploy static content with languages and themes"
  su www-data -s /bin/bash -c "php bin/magento setup:static-content:deploy -f --no-interaction --jobs ${ENV_MAGE_STATIC_JOBS}  --content-version=${ARTIFAKT_BUILD_ID} --theme=${ENV_MAGE_THEME:-all} --exclude-theme=${ENV_MAGE_THEME_EXCLUDE:-none} --language=${ENV_MAGE_LANG:-all} --exclude-language=${ENV_MAGE_LANG_EXCLUDE:-none}"
  ls -la /data/var
  
  #8 - Flush cache
  echo "#8 - Flush cache"
  su www-data -s /bin/bash -c 'php bin/magento cache:flush'
  
fi # end of "Check if Magento is installed"
