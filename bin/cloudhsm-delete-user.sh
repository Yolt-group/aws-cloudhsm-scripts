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

deleteUser() {
  NS=$(echo $1 | jq -r '.namespace')
  PODS=$(echo $1 | jq -rc '.pods | .[]')
  ACCOUNT=$(echo $1 | jq -r '.account')
  CU_NAME=$(echo $1 | jq -r '.username')

  check_env NS
  check_env PODS
  check_env ACCOUNT
  check_env CU_NAME

  # Could fail if CU does not exists.
  delete-crypto-user.exp $CO_NAME $CO_PW $CU_NAME
}

listUsers() {
  list-users.exp
}

CMDS=$(jq -c '.[]' < $INPUT)
for CMD in $CMDS ; do
  NAME=$(echo $CMD | jq -r '.command')
  ARGS=$(echo $CMD | jq -c '.args')
  case "$NAME" in
    deleteUser)
      deleteUser $ARGS
      ;;
    listUsers)
      listUsers
      ;;
    *)
      echo Unkwnown command name: $NAME
      exit 1
  esac
done

