FROM registry.artifakt.io/magento:2.4
ARG CODE_ROOT=.
ENV ARTIFAKT_PHP_FPM_PORT=9000

USER root

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Run artifakt_scripts/composer_auth.sh
# Run artifakt_scripts/composer_setup.sh
# hadolint ignore=SC1091

RUN --mount=source=artifakt-custom-build-args,target=/tmp/build-args \
if [ -f /tmp/build-args ]; then source /tmp/build-args; fi && \
if [ -f /artifakt_scripts/composer_setup.sh ]; then /artifakt_scripts/composer_setup.sh; fi  && \
if [ -f /var/www/html/.artifakt/composer_auth.sh ]; then /var/www/html/.artifakt/composer_auth.sh; fi 


# Run artifakt_scripts/node_install.sh
RUN --mount=source=artifakt-custom-build-args,target=/tmp/build-args \
if [ -f /tmp/build-args ]; then source /tmp/build-args; fi && \
if [ -f /artifakt_scripts/node_install.sh ]; then /artifakt_scripts/node_install.sh; fi

COPY --chown=www-data:www-data $CODE_ROOT /var/www/html/

# Run artifakt_scripts/custom_code_root_setup.sh
RUN --mount=source=artifakt-custom-build-args,target=/tmp/build-args \
if [ -f /tmp/build-args ]; then source /tmp/build-args; fi && \
if [ -f /artifakt_scripts/custom_code_root_setup.sh ]; then /artifakt_scripts/custom_code_root_setup.sh; fi

# Copy the artifakt folder on root
RUN  if [ -d .artifakt ]; then cp -rp /var/www/html/.artifakt/ /.artifakt/; fi

# run custom scripts apt_get_install.sh
# hadolint ignore=SC1091
RUN --mount=source=artifakt-custom-build-args,target=/tmp/build-args \
  if [ -f /tmp/build-args ]; then source /tmp/build-args; fi && \
  if [ -f /var/www/html/.artifakt/apt_get_install.sh ]; then /var/www/html/.artifakt/apt_get_install.sh; fi

# Checks if default.conf file exists, if not, it'll copy the template file from our artifakt_templates folder to the client .artifakt/nginx folder
#RUN if [ ! -f .artifakt/nginx/default.conf ]; then mkdir -p .artifakt/nginx && cp /artifakt_templates/nginx/default.conf .artifakt/nginx/ && chown www-data:www-data -R .artifakt/nginx; fi

WORKDIR /var/www/html

USER www-data

# Run artifakt_scripts/composer_composer_install.sh
RUN --mount=source=artifakt-custom-build-args,target=/tmp/build-args \
  if [ -f /tmp/build-args ]; then source /tmp/build-args; fi && \
  if [ -f /artifakt_scripts/composer_install.sh ]; then /artifakt_scripts/composer_install.sh; fi

RUN if [ ! -f "app/etc/config.php" ]; then echo "File not found, running generation." && php bin/magento module:enable --all; else echo "File already exists."; fi

# Run artifakt_scripts/composer_autoload.sh
# hadolint ignore=SC1091
RUN --mount=source=artifakt-custom-build-args,target=/tmp/build-args \
  if [ -f /tmp/build-args ]; then source /tmp/build-args; fi && \
  if [ -f /artifakt_scripts/composer_autoload.sh ]; then /artifakt_scripts/composer_autoload.sh; fi

RUN chown -R www-data:www-data /var/www/html && \
  find var generated vendor pub/static pub/media app/etc -type f -exec chmod g+w {} + && \
  find var generated vendor pub/static pub/media app/etc -type d -exec chmod g+ws {} +

RUN --mount=source=artifakt-custom-build-args,target=/tmp/build-args \
  if [ -f /tmp/build-args ]; then source /tmp/build-args; fi && \
  if [ -f /artifakt_scripts/magento_statics.sh ]; then /artifakt_scripts/magento_statics.sh; fi

USER root

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Run artifakt_scripts/newrelic_install.sh
# Run artifakt_scripts/blackfire_install.sh
# hadolint ignore=SC1091

RUN --mount=source=artifakt-custom-build-args,target=/tmp/build-args \
  if [ -f /tmp/build-args ]; then source /tmp/build-args; fi && \
  if [ -f /artifakt_scripts/newrelic_install.sh ]; then /artifakt_scripts/newrelic_install.sh; fi && \
  if [ -f /artifakt_scripts/blackfire_install.sh ]; then /artifakt_scripts/blackfire_install.sh; fi

# Run custom scripts build.sh
# hadolint ignore=SC1091
RUN --mount=source=artifakt-custom-build-args,target=/tmp/build-args \
  if [ -f /tmp/build-args ]; then source /tmp/build-args; fi && \
  if [ -f /.artifakt/build.sh ]; then /.artifakt/build.sh; fi

RUN apt-get update && apt-get install -yq libfcgi-bin unzip && rm -rf /var/lib/apt/lists/*

HEALTHCHECK --interval=30s --timeout=3s \
  CMD cgi-fcgi -bind -connect localhost:$ARTIFAKT_PHP_FPM_PORT