FROM registry.artifakt.io/magento:2.4-apache

ARG CODE_ROOT=.

COPY --chown=www-data:www-data $CODE_ROOT /var/www/html/

WORKDIR /var/www/html/

RUN [ -f composer.lock ] && composer install --no-cache --optimize-autoloader --no-interaction --no-ansi --no-dev || true

# copy the artifakt folder on root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN  if [ -d .artifakt ]; then cp -rp /var/www/html/.artifakt /.artifakt/; fi

# PERSISTENT DATA FOLDERS
RUN cd /var/www/html && rm -rf pub/media pub/static/_cache var/export && \
  mkdir -p /data/pub/media /data/pub/static /data/var/export /data/generated && \
  ln -snf /data/pub/media /var/www/html/pub/media && \
  ln -snf /data/pub/static /var/www/html/pub/static && \
  ln -snf /data/generated /var/www/html/generated && \
  ln -snf /data/var/export /var/www/html/var/export && \
  chown -R www-data:www-data /data/pub /data/var /data/generated /var/www/html/pub /var/www/html/var /var/www/html/generated

# FAILSAFE LOG FOLDER
RUN rm -rf /var/www/html/var/log && \
  mkdir -p /var/log/artifakt/log && \
  ln -snf /var/log/artifakt/log /var/www/html/var/log && \
  chown -R www-data:www-data /var/log/artifakt

RUN rm -rf /var/www/html/var/report && \
  mkdir -p /var/log/artifakt/report && \
  ln -snf /var/log/artifakt/report /var/www/html/var/report && \
  chown -R www-data:www-data /var/log/artifakt /var/www/html/var/report

# run custom scripts build.sh
# hadolint ignore=SC1091
RUN --mount=source=artifakt-custom-build-args,target=/tmp/build-args \
  if [ -f /tmp/build-args ]; then source /tmp/build-args; fi && \
  if [ -f /.artifakt/build.sh ]; then /.artifakt/build.sh; fi

# fix perms/owner
RUN chown -R www-data:www-data /data /var/www/html/

