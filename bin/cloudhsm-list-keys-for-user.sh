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

listKeysForUser() {
  echo "Initializing values"
  CU_NAME=$(echo $1 | jq -r '.originUserName')
  NS=$(echo $1 | jq -r '.namespace')
  ACCOUNT=$(echo $1 | jq -r '.account')

  USER_ID=$(echo $1 | jq -r '.userID')

  check_env CU_NAME
  check_env NS
  check_env ACCOUNT
  check_env USER_ID

  echo "Getting vault entry"

  CU_PW=$(vault kv get -field HSM_PASSWORD $SECURITY_TARGET/k8s/pods/cloudhsm/kv/cloudhsm-users/crypto/$ACCOUNT/$NS)

  check_env CU_PW

  echo "Get keyhandles with cloudhsm util"
  list-keys-for-user.exp $CO_NAME $CO_PW $USER_ID

  NUMBEROFKEYS=$(cat /tmp/$USER_ID.out | sed '2q;d' | sed 's/Number of keys found //g')

  if [ $NUMBEROFKEYS -gt 0 ]
  then
    echo "Keyhandles to iterate over:"
    KEYHANDLES=$(cat /tmp/$USER_ID.out | sed '4q;d' | sed 's/(o)//g' | sed 's/(s)//g')
    echo $KEYHANDLES

    echo "Getting keylabels for the keyhandles with cloudhsmutil"

    get-label-for-keyhandle.exp $CU_NAME $CU_PW $KEYHANDLES
  else
    echo "No keys found"
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
    listKeysForUser)
      listKeysForUser $ARGS
      ;;
    listUsers)
      listUsers
      ;;
    *)
      echo Unknown command name: $NAME
      exit 1
  esac
done

