# CloudHSM Docker Image

This repository is intended for non-interactive access to AWS CloudHSM clusters. It allows for the creation of CI/CD 
pipelines (not included) in which peer-reviewed and approved actions can be staged for deploying against CloudHSM 
cluster.

The docker image contains binaries for interacting with:

* __CloudHSM__ (_expect_ scripts):
  * Create crypto users (CU)
  * List users of an HSM
  * Get overview of keys for a given CU
  * Share/unshare keys of a specified source-CU with a specified target CU and list of key-IDs
  * Delete users/keys
