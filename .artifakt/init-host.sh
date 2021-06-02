#!/bin/bash

set -e

# TODO on starter only
# ignore on pro/entreprise
MAIN_INSTANCE=$(sudo docker ps -q -f "label=artifakt.io/is_main_instance=1")

if [ "$MAIN_INSTANCE" != "" ]; then
  #TODO STEP1 run elasticsearch
  sudo docker cp ${MAIN_INSTANCE}:/.artifakt/docker-compose.yaml /tmp/docker-compose.yaml

  sudo docker-compose --file=/tmp/docker-compose.yaml --project-name=magento2 up --remove-orphans -d

  #TODO STEP3 install crontab
  sudo docker cp ${MAIN_INSTANCE}:/etc/cron.d/magento2-cron crontab
fi;
