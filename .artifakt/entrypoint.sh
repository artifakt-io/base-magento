#!/bin/bash
set -e

ENTRYPOINT_MYSQL_HOST=${ARTIFAKT_MYSQL_HOST:-"mysql"}
ENTRYPOINT_REDIS_HOST=${ARTIFAKT_REDIS_HOST:-"redis"}

echo ">>>>>>>>>>>>>> START CUSTOM ENTRYPOINT SCRIPT <<<<<<<<<<<<<<<<< "

# wait for database to be ready
/.artifakt/wait-for-it.sh $ENTRYPOINT_MYSQL_HOST:3306

# https://devdocs.magento.com/guides/v2.4/config-guide/redis/redis-session.html
if [ ! -f "/var/www/html/app/etc/env.php" ]; then 
  echo "File not found, running generation." 
  su www-data -s /bin/bash -c "./bin/magento setup:install --backend-frontname=admin123 \
  --db-host=$ENTRYPOINT_MYSQL_HOST --db-name=$ARTIFAKT_MYSQL_DATABASE_NAME --db-user=$ARTIFAKT_MYSQL_USER --db-password=$ARTIFAKT_MYSQL_PASSWORD \
  --admin-firstname=Magento --admin-lastname=User --admin-email=user@example.com \
  --admin-user=admin --admin-password=admin123 --language=fr_FR \
  --session-save=redis --session-save-redis-host=$ENTRYPOINT_REDIS_HOST \
  --cache-backend=redis --cache-backend-redis-server=$ENTRYPOINT_REDIS_HOST --cache-backend-redis-db=0 \
  --page-cache=redis --page-cache-redis-server=$ENTRYPOINT_REDIS_HOST --page-cache-redis-db=1 \
  --currency=EUR --timezone=Europe/Paris --use-rewrites=1 \
  --search-engine=elasticsearch7 --elasticsearch-host=elasticsearch \
  --elasticsearch-port=9200"  
fi

su www-data -s /bin/bash -c "./bin/magento maintenance:enable"
su www-data -s /bin/bash -c "./bin/magento deploy:mode:set production"
su www-data -s /bin/bash -c "./bin/magento setup:upgrade && ./bin/magento setup:di:compile && ./bin/magento setup:static-content:deploy -f fr_FR en_US --no-interaction --jobs 5"

if [ ! -f "/var/www/html/app/etc/env.php" ]; then 
  su www-data -s /bin/bash -c "./bin/magento config:set -n web/secure/use_in_adminhtml 1"
  su www-data -s /bin/bash -c "./bin/magento config:set -n web/secure/enable_upgrade_insecure 1"
  #You need to configure Two-Factor Authorization in order to proceed to your store's admin area
  #su www-data -s /bin/bash -c "./bin/magento module:disable Magento_TwoFactorAuth"
  #su www-data -s /bin/bash -c "./bin/magento security:recaptcha:disable-for-user-login"
  su www-data -s /bin/bash -c "./bin/magento setup:config:set --backend-frontname=admin123"
  su www-data -s /bin/bash -c "./bin/magento cache:clean config && ./bin/magento cache:flush"
  su www-data -s /bin/bash -c "./bin/magento config:set -n web/secure/base_url https://$VIRTUAL_HOST/"
  su www-data -s /bin/bash -c "./bin/magento config:set -n web/unsecure/base_url http://$VIRTUAL_HOST/"
fi

su www-data -s /bin/bash -c "./bin/magento maintenance:disable"

su www-data -s /bin/bash -c "./bin/magento config:show"
su www-data -s /bin/bash -c "cat ./app/etc/env.php"

echo ">>>>>>>>>>>>>> END CUSTOM ENTRYPOINT SCRIPT <<<<<<<<<<<<<<<<< "
