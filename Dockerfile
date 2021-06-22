FROM registry.artifakt.io/magento:2.4-apache

COPY --chown=www-data:www-data . /var/www/html/

USER www-data
#authjson
RUN [ -f composer.lock ] && composer install --no-cache --no-interaction --no-dev || true
RUN php bin/magento setup:di:compile
RUN composer dump-autoload --no-dev --optimize --apcu
RUN php bin/magento setup:static-content:deploy -f --no-interaction --jobs 5
USER root

# copy the artifakt folder on root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN if [ -d .artifakt ]; then cp -rp /var/www/html/.artifakt/* /.artifakt/; fi

# run custom scripts build.sh
# hadolint ignore=SC1091
RUN if [ -f /.artifakt/build.sh ]; then /.artifakt/build.sh; fi