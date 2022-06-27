#!/bin/bash

[ "$DEBUG" = "true" ] && set -x

php bin/magento setup:install \
  --admin-email="email@example.com" \
  --admin-firstname="John" \
  --admin-lastname="Doe" \
  --admin-password="password123" \
  --admin-use-security-key="1" \
  --admin-user="admin" \
  --backend-frontname="admin" \
  --base-url="http://localhost/" \
  --cache-backend-redis-db="0" \
  --cache-backend-redis-password='' \
  --cache-backend-redis-port="${ARTIFAKT_REDIS_PORT}" \
  --cache-backend-redis-server="${ARTIFAKT_REDIS_HOST}" \
  --cache-backend='redis' \
  --cleanup-database \
  --consumers-wait-for-messages=0 \
  --currency="USD" \
  --db-host="${ARTIFAKT_MYSQL_HOST}" \
  --db-name="${ARTIFAKT_MYSQL_DATABASE_NAME}" \
  --db-password="${ARTIFAKT_MYSQL_PASSWORD}" \
  --db-user="${ARTIFAKT_MYSQL_USER}" \
  --document-root-is-pub="1" \
  --elasticsearch-enable-auth='0' \
  --elasticsearch-host="${ARTIFAKT_ES_HOST}" \
  --elasticsearch-index-prefix="magento2" \
  --elasticsearch-port="${ARTIFAKT_ES_PORT}" \
  --elasticsearch-timeout="15" \
  --language="en_US" \
  --page-cache-redis-db="1" \
  --page-cache-redis-password='' \
  --page-cache-redis-port="${ARTIFAKT_REDIS_PORT}" \
  --page-cache-redis-server="${ARTIFAKT_REDIS_HOST}" \
  --page-cache='redis' \
  --search-engine=elasticsearch7 \
  --session-save-redis-db="2" \
  --session-save-redis-disable-locking="1" \
  --session-save-redis-host="${ARTIFAKT_REDIS_HOST}" \
  --session-save-redis-max-concurrency="60" \
  --session-save-redis-password='' \
  --session-save-redis-port="${ARTIFAKT_REDIS_PORT}" \
  --session-save='redis' \
  --timezone="Europe/Paris" \
  --use-rewrites="1" \
  --use-secure-admin="1" \
  --use-secure="0"
