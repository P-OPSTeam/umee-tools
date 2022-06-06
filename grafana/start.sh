#! /bin/bash

#### Fill up all the variable below
PD_INTEGRATION_KEY="<ur_pd_integration_key>"
ADMIN_USER="admin" #change if you want
ADMIN_PASSWORD="<urpwd>"
ETH_RPC=https://mainnet.infura.io/****KEYHERE
ORCHESTRATOR_ETH_ADDRESS=0xyouraddress

#### no more variable to change/set

cp conf/prometheus/prometheus.yml.tpl conf/prometheus/prometheus.yml
sed -i "s/PUBLIC_IP/$(curl -s ifconfig.me)/g" conf/prometheus/prometheus.yml

cp conf/alertmanager.yaml.tpl conf/alertmanager.yaml
sed -i "s/PD_SERVICE_KEY/${PD_INTEGRATION_KEY}/g" conf/alertmanager.yaml

echo "orch_eth:$ORCHESTRATOR_ETH_ADDRESS" > conf/eth_exporter_addresses.txt

ADMIN_USER=${ADMIN_USER} \
ADMIN_PASSWORD=${ADMIN_PASSWORD} \
GF_USERS_ALLOW_SIGN_UP=false \
PROMETHEUS_CONFIG="./data/prometheus.yml" \
GRAFANA_CONFIG="./data/grafana.ini" \
ETH_RPC=${ETH_RPC} \
docker-compose up -d --remove-orphans --build "$@"

sudo chown -R $USER:$USER data