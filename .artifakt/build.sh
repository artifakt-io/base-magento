#!/bin/bash

[ "$DEBUG" = "true" ] && set -x

ROOT=/var/log/artifakt

echo Init persistent folder $ROOT
mkdir -p $ROOT

echo Copy modified/new files from container /var/www/html/var/log to volume $ROOT
cp -ur /var/www/html/var/log/* $ROOT || true

echo Link $ROOT directory to /var/www/html/var/log
rm -rf /var/www/html/var/log && \
  mkdir -p /var/www/html && \
  ln -sfn $ROOT /var/www/html/var/log && \
  chown -h -R -L www-data:www-data /var/www/html/var/log $ROOT

echo "replace standard docker-entrypoint to manage persistent folders in custom entrypoint"
cp /.artifakt/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
chmod +x /usr/local/bin/docker-entrypoint.sh
