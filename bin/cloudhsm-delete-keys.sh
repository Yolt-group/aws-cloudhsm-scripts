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

export VAULT_TOKEN=$(cat /opt/cloudhsm/etc/token)

deleteKeys() {
  # Get crypto User (CU) password from Vault.
  echo "Initializing values"
  CU_NAME=$(echo $1 | jq -r '.originUserName')
  NS=$(echo $1 | jq -r '.namespace')
  ACCOUNT=$(echo $1 | jq -r '.account')

  check_env CU_NAME
  check_env NS
  check_env ACCOUNT

  echo "Getting vault entry"

  CU_PW=$(vault kv get -field HSM_PASSWORD $SECURITY_TARGET/k8s/pods/cloudhsm/kv/cloudhsm-users/crypto/$ACCOUNT/$NS)

  check_env CU_PW

  echo "Start cloudhsmclient service"
  /opt/cloudhsm/bin/cloudhsm_client /opt/cloudhsm/etc/cloudhsm_client.cfg 2>&1 > /dev/null &
  sleep 40s

  echo "Commencing deleteKeys"

  check_env CU_NAME
  for KEY_ID in $(echo $1 | jq -c '.keyID[]'); do
    delete-keys.exp $CU_NAME $CU_PW $KEY_ID
  done
}

listUsers() {
  echo "commencing listUsers"
  list-users.exp
}

CMDS=$(jq -c '.[]' < $INPUT)
for CMD in $CMDS ; do
  NAME=$(echo $CMD | jq -r '.command')
  ARGS=$(echo $CMD | jq -c '.args')
  case "$NAME" in
    deleteKeys)
      deleteKeys $ARGS
      ;;
    listUsers)
      listUsers
      ;;
    *)
      echo Unkwnown command name: $NAME
      exit 1
  esac
done

