#!/bin/bash

set -e

INPUT=$1

function check_env {
  if [ -z "${!1}" ]; then
    echo $1 undefined
    exit 1
  fi
}

check_env VAULT_ADDR
check_env SECURITY_TARGET
check_env INPUT

configure-clients.sh

# Get crypto officer (CO) password from Vault.
CO_NAME=pipeline
CO_PW=$(cat /opt/cloudhsm/etc/crypto-officers-pw)

export VAULT_TOKEN=$(cat /opt/cloudhsm/etc/token)

createUser() {
  NS=$(echo $1 | jq -r '.namespace')
  PODS=$(echo $1 | jq -rc '.pods | .[]')
  ACCOUNT=$(echo $1 | jq -r '.account')
  CU_NAME=$(echo $1 | jq -r '.username')
  CU_PW=$(openssl rand -base64 21)

  check_env NS
  check_env PODS
  check_env ACCOUNT
  check_env CU_NAME

  # Could fail if CU already exists.
  if create-crypto-user.exp $CO_NAME $CO_PW $CU_NAME $CU_PW ; then
    for POD in $PODS ; do
      vault kv put -format=json $SECURITY_TARGET/k8s/pods/cloudhsm/kv/cloudhsm-users/$POD/$ACCOUNT/$NS \
        HSM_PARTITION=PARTITION_1 \
        HSM_USER=$CU_NAME \
        HSM_PASSWORD=$CU_PW
    done
  fi
}

listUsers() {
  list-users.exp
}

CMDS=$(jq -c '.[]' < $INPUT)
for CMD in $CMDS ; do
  NAME=$(echo $CMD | jq -r '.command')
  ARGS=$(echo $CMD | jq -c '.args')
  case "$NAME" in
    createUser)
      createUser $ARGS
      ;;
    listUsers)
      listUsers
      ;;
    *)
      echo Unkwnown command name: $NAME
      exit 1
  esac
done

