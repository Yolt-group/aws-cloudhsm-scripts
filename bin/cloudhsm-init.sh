#!/bin/bash

set -x
set -eo pipefail

DATA=/opt/cloudhsm/data

function check_env {
  if [ -z "${!1}" ]; then
    echo $1 undefined
    exit 1
  fi
}

check_env VAULT_ADDR
check_env SECURITY_TARGET

export VAULT_TOKEN=$(cat /opt/cloudhsm/etc/token)

# Get cloudhsm clusters that are uninitialized.
CLUSTERS=$(aws cloudhsmv2 --output=json describe-clusters --filters=states=UNINITIALIZED)
if ! echo $CLUSTERS | jq -e -r ".Clusters[0]" ; then
  echo "No unitialized custers found."
  exit 1
fi

CLUSTER_ID=$(echo $CLUSTERS | jq -e -r ".Clusters[0].ClusterId")
if [ -z "$CLUSTER_ID" ]; then
  echo No uninitialized clusters found.
  exit 1
fi

# Get certificates from uninitialized cluster.
echo $CLUSTERS | jq -e '.Clusters[0]' | tee \
  >(jq -e -r ".Certificates.ClusterCsr" > $DATA/ClusterCsr.csr) \
  >(jq -e -r '.Certificates.HsmCertificate' > $DATA/HsmCertificate.crt) \
  >(jq -e -r '.Certificates.AwsHardwareCertificate' > $DATA/AwsHardwareCertificate.crt) \
  >(jq -e -r '.Certificates.ManufacturerHardwareCertificate' > $DATA/ManufacturerHardwareCertificate.crt)
  >/dev/null

# Verify the HSM certificate with the AWS CloudHSM root certificate.
cat $DATA/AwsHardwareCertificate.crt $DATA/AWS_CloudHSM_Root-G1.crt > $DATA/AWS_chain.crt
openssl verify -CAfile $DATA/AWS_chain.crt -partial_chain $DATA/HsmCertificate.crt >/dev/null 2>&1

# Verify the HSM certificate with the manufacturer root certificate.
cat $DATA/ManufacturerHardwareCertificate.crt $DATA/liquid_security_certificate.crt > $DATA/manufacturer_chain.crt
openssl verify -CAfile $DATA/manufacturer_chain.crt -partial_chain $DATA/HsmCertificate.crt >/dev/null 2>&1

# Verify pub keys are the same.
openssl x509 -in $DATA/HsmCertificate.crt -pubkey -noout > $DATA/HsmCertificate.pub
openssl req -in $DATA/ClusterCsr.csr -pubkey -noout > $DATA/ClusterCsr.pub
if ! diff $DATA/HsmCertificate.pub $DATA/ClusterCsr.pub >/dev/null ; then
  echo "Identified difference in pub keys! Exiting"
  exit 1
fi

# Sign certificate and spit out CA and signed certificate.
cat $DATA/ClusterCsr.csr | vault write $SECURITY_TARGET/cloudhsm/sign/initialize ttl=78840h csr=-
RESULT=$(cat $DATA/ClusterCsr.csr | vault write -format json $SECURITY_TARGET/cloudhsm/sign/initialize ttl=78840h csr=-)
TRUST_ANCHOR="$(echo $RESULT | jq -e -r '.data.issuing_ca')"
SIGNED_CERT="$(echo $RESULT | jq -e -r '.data.certificate')"

# Initialize cluster.
aws cloudhsmv2 initialize-cluster --cluster-id $CLUSTER_ID --signed-cert "$SIGNED_CERT" --trust-anchor "$TRUST_ANCHOR"
echo Successfully initialized cluster $CLUSTER_ID
