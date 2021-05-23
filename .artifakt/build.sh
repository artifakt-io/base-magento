#!/bin/bash

set -e

echo ">>>>>>>>>>>>>> START MAGENTO2 BUILD SCRIPT <<<<<<<<<<<<<<<<< "

echo "------------------------------------------------------------"
echo "The following build args are available:"
env
echo "------------------------------------------------------------"

MAGENTO_VERSION=2.4.2
INSTALL_DIR=/var/www/html
COMPOSER_HOME=/var/www/

cd $INSTALL_DIR

#downgrade composer to v1
COMPOSER_VERSION=1.10.22
curl -sS https://getcomposer.org/installer | \
  php -- --version=${COMPOSER_VERSION} --install-dir=/usr/local/bin --filename=composer

COMPOSER_MEMORY_LIMIT=-1 composer update 

mkdir -p $INSTALL_DIR/var/composer_home && ls -la $INSTALL_DIR/var/composer_home
if [[ -f $COMPOSER_HOME/auth.json ]]; then
  cp -p $COMPOSER_HOME/auth.json $INSTALL_DIR/var/composer_home/auth.json
fi

#ls -la /var/www/html
./bin/magento module:enable --all
./bin/magento setup:di:compile

echo "CHECKING FOR ANY ERROR"

php -d display_errors ./bin/magento

echo "PRINTING MODULE STATUS"

php -d display_errors ./bin/magento module:status

chown -R www-data:www-data $INSTALL_DIR

echo ">>>>>>>>>>>>>> END CUSTOM BUILD SCRIPT <<<<<<<<<<<<<<<<< "

