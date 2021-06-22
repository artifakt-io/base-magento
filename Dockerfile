FROM registry.artifakt.io/magento:2.4-apache

COPY --chown=www-data:www-data . /var/www/html/

USER www-data
RUN [ -f composer.lock ] && composer install --no-cache --no-interaction --no-dev || true
RUN [ ! -f app/etc/config.php ] && php bin/magento module:enable --all || true
RUN php bin/magento setup:di:compile
RUN composer dump-autoload --no-dev --optimize --apcu
RUN php bin/magento setup:static-content:deploy -f --no-interaction --jobs 5