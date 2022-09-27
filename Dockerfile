FROM registry.artifakt.io/magento:2.4

ARG CODE_ROOT=.
USER root

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Run artifakt_scripts/composer_install.sh
# hadolint ignore=SC1091
RUN --mount=source=artifakt-custom-build-args,target=/tmp/build-args \
  if [ -f /tmp/build-args ]; then source /tmp/build-args; fi && \
  if [ -f /artifakt_scripts/composer_install.sh ]; then /artifakt_scripts/composer_install.sh; fi

RUN --mount=source=artifakt-custom-build-args,target=/tmp/build-args \
  if [ -f /tmp/build-args ]; then source /tmp/build-args; fi && \
  if [ -f /artifakt_scripts/node_install.sh ]; then /artifakt_scripts/node_install.sh; fi

COPY --chown=www-data:www-data $CODE_ROOT /var/www/html/
RUN  if [ -d .artifakt ]; then cp -rp /var/www/html/.artifakt/ /.artifakt/; fi

# Checks if default.conf file exists, if not, it'll copy the template file from our artifakt_templates folder to the client .artifakt/nginx folder
#RUN if [ ! -f .artifakt/nginx/default.conf ]; then ls /artifakt_templates && mkdir -p .artifakt/nginx && cp /artifakt_templates/nginx/default.conf .artifakt/nginx/ && chown www-data:www-data -R .artifakt/nginx; fi

WORKDIR /var/www/html
USER www-data
RUN [ -f composer.lock ] && composer install --no-cache --no-interaction --no-ansi --no-dev || true
RUN php bin/magento module:enable --all
RUN php bin/magento setup:di:compile
RUN composer dump-autoload --no-dev --optimize --apcu

RUN --mount=source=artifakt-custom-build-args,target=/tmp/build-args \
  if [ -f /tmp/build-args ]; then source /tmp/build-args; fi && \
  if [ -f /artifakt_scripts/magento_statics.sh ]; then /artifakt_scripts/magento_statics.sh; fi

USER root
# copy the artifakt folder on root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN --mount=source=artifakt-custom-build-args,target=/tmp/build-args \
  if [ -f /tmp/build-args ]; then source /tmp/build-args; fi && \
  if [ -f /artifakt_scripts/magento_statics.sh ]; then /artifakt_scripts/newrelic_install.sh; fi

# run custom scripts build.sh
# hadolint ignore=SC1091
RUN --mount=source=artifakt-custom-build-args,target=/tmp/build-args \
  if [ -f /tmp/build-args ]; then source /tmp/build-args; fi && \
  if [ -f /.artifakt/build.sh ]; then /.artifakt/build.sh; fi