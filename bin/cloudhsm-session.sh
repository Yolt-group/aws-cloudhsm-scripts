#!/bin/bash

set -e

function check_env {
  if [ -z "${!1}" ]; then
    echo $1 undefined
    exit 1
  fi
}

check_env VAULT_ADDR
check_env POD_NAMESPACE
check_env POD_NAME
check_env SECURITY_TARGET
check_env CLUSTER_INDEX

export ENVIRONMENT=$SECURITY_TARGET

configure-clients.sh

echo "export VAULT_ADDR=$VAULT_ADDR" >> $HOME/.bash_profile
echo "export POD_NAMESPACE=$POD_NAMESPACE" >> $HOME/.bash_profile
echo "export POD_NAME=$POD_NAME" >> $HOME/.bash_profile
echo "export SECURITY_TARGET=$SECURITY_TARGET" >> $HOME/.bash_profile
echo "export CLUSTER_INDEX=$CLUSTER_INDEX" >> $HOME/.bash_profile
echo "export ENVIRONMENT=$SECURITY_TARGET" >> $HOME/.bash_profile

sleep infinity