#!/bin/bash

set -e

INPUT=$1

function check_env {
  if [ -z "${!1}" ]; then
    echo $1 undefined
    exit 1
  fi
}

check_env INPUT

configure-clients.sh

# Get crypto officer (CO) password from Vault.
CO_NAME=pipeline
CO_PW=$(cat /opt/cloudhsm/etc/crypto-officers-pw)

listAllKeys() {
  echo "get data with cloudhsm util"
  list-all-keys.exp $CO_NAME $CO_PW
}

listUsers() {
  list-users.exp
}

CMDS=$(jq -c '.[]' < $INPUT)
for CMD in $CMDS ; do
  NAME=$(echo $CMD | jq -r '.command')
  ARGS=$(echo $CMD | jq -c '.args')
  case "$NAME" in
    listAllKeys)
      listAllKeys $ARGS
      ;;
    listUsers)
      listUsers
      ;;
    *)
      echo Unkwnown command name: $NAME
      exit 1
  esac
done
