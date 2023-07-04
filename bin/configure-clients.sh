#!/bin/bash

set -e

# Copy in existing original trust store and add our own CA.
cp -r /opt/cloudhsm/etc_original/certs /opt/cloudhsm/etc/
cp /opt/cloudhsm/etc/customerCA.crt /opt/cloudhsm/etc/certs/$(openssl x509 -in /opt/cloudhsm/etc/customerCA.crt -hash | head -n 1)

# Create management config with all HSM addresses.
HSM_ADDRESSES=$(aws cloudhsmv2 --filters=states=ACTIVE --output=json describe-clusters | jq -r '.Clusters | sort_by(.CreateTimestamp) | .[0].Hsms | map(select (.State == "ACTIVE")) | map(.EniIp) | join(",")')
unset HTTPS_PROXY

# Management client configuration (CO).
jq -r --arg hosts $HSM_ADDRESSES \
  '.servers[0] as $template | .servers = (($hosts | split(",") | map( . as $element | ($template | (.hostname |= $element) | (.name |= $element)))))' \
  < /opt/cloudhsm/etc_original/cloudhsm_mgmt_util.cfg > /opt/cloudhsm/etc/cloudhsm_mgmt_util.cfg

# Regular client configuration (CU).
HSM_ADDRESS=$(echo $HSM_ADDRESSES | awk -F, '{ print $1 }')
jq -r --arg hostname $HSM_ADDRESS \
  '.loadbalance.prefer_same_zone = "no" | .server.hostname = $hostname' \
  < /opt/cloudhsm/etc_original/cloudhsm_client.cfg > /opt/cloudhsm/etc/cloudhsm_client.cfg

