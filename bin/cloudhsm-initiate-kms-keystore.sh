#!/bin/bash

function check_env {
  if [ -z "${!1}" ]; then
    echo $1 undefined
    exit 1
  fi
}

echo "Start initialization"

configure-clients.sh

# TODO: Migrate to secrets pipeline
# Get crypto officer (CO) password from Vault.
CO_NAME=pipeline
CO_PW=$(cat /opt/cloudhsm/etc/crypto-officers-pw)

echo "Initiatized CO"

# Get AWS cluster-ID being initialized
CLUSTER_ID=$(aws cloudhsmv2 describe-clusters --filters=states=ACTIVE | jq -e -r ".Clusters[0].ClusterId")
if [ -z "$CLUSTER_ID" ]; then
  echo No initialized clusters found.
  exit 1
fi

echo "Retrieved cluster ID"

TRUST_ANCHOR_CERTIFICATE="file://opt/cloudhsm/etc/customerCA.crt"

CU_NAME="kmsuser"
# TODO: Migrate to secrets pipeline
# Get kms (CO) password from Vault.
KMS_PWD=$(cat /opt/cloudhsm/etc/kms-user-pw)

echo "Got trust anchor and KMS PWD"
createUserHSMVaultSynced() {
    echo "start createUserHSMVaultSynced"

    create-crypto-user.exp "$CO_NAME" "$CO_PW" "$CU_NAME" "$KMS_PWD"
    EXITSTATUS=$?
    if [ $EXITSTATUS -ne 0 ] && [ $EXITSTATUS -ne 2 ]; then
      echo "failed creation of user"
      exit 1
    fi
    echo "end createUserHSMVaultSynced"
}

createKMSCustomKeyStore(){
  echo "start createKMSCustomKeyStore"
    aws kms create-custom-key-store --output json \
        --custom-key-store-name DataScienceKeyStore \
        --cloud-hsm-cluster-id "$CLUSTER_ID" \
        --key-store-password "$KMS_PWD" \
        --trust-anchor-certificate "$TRUST_ANCHOR_CERTIFICATE" > /tmp/keystore.json
    aws kms connect-custom-key-store --cli-input-json file:///tmp/keystore.json

  echo "end createKMSCustomKeyStore"
}


createUserHSMVaultSynced
createKMSCustomKeyStore
