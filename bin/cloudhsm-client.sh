#!/bin/bash

set -e

configure-clients.sh

/opt/cloudhsm/bin/cloudhsm_client /opt/cloudhsm/etc/cloudhsm_client.cfg
