#!/bin/bash

set -e

# on starter only
# ignore on pro/entreprise

ID=$(sudo docker ps -ql)

#TODO STEP1 run elasticsearch
sudo docker cp ${ID}:/.artifakt/docker-compose.yaml /tmp/docker-compose.yaml

sudo docker-compose --file=/tmp/docker-compose.yaml --project-name=magento2 up --remove-orphans -d

#TODO STEP3 install crontab
sudo docker cp ${ID}:/etc/cron.d/magento2-cron crontab
