FROM registry.artifakt.io/magento:2.4-apache

ENV PHP_MEMORY_LIMIT -1
RUN [ -n "${PHP_MEMORY_LIMIT}" ] && sed -i "s/4G/${PHP_MEMORY_LIMIT}/" /usr/local/etc/php/conf.d/magento.ini

COPY --chown=www-data:www-data . /var/www/html/

RUN [ -f composer.lock ] && composer install --no-cache --no-interaction --ansi --no-dev || true
RUN [ ! -f app/etc/config.php ] && php bin/magento module:enable --all
RUN php bin/magento setup:di:compile
#RUN composer dump-autoload --no-dev --optimize --apcu
#RUN php bin/magento setup:static-content:deploy --ansi --no-interaction --jobs 5