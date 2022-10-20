#!/bin/bash

PROFILE=$1
CLUSTER_NAME=$2
ACCOUNT_ID=$3


# replace variables
set -e

if [ "x${CLUSTER_NAME}" != "x" ]
then
    echo "cluster name is ${CLUSTER_NAME}"
    sed 's/VAR_CLUSTER_NAME/'"${CLUSTER_NAME}"'/g' values/velero/iamserviceaccount-velero.yaml > values/velero/cn-iamserviceaccount-velero.yaml
else
    echo ">>> cluster name is empty!!!"
    exit
fi

if [ "x${ACCOUNT_ID}" != "x" ]
then
    echo "account id is ${ACCOUNT_ID}"
    sed 's/VAR_ACCOUNT_ID/'"${ACCOUNT_ID}"'/g' values/velero/cn-iamserviceaccount-velero.yaml > values/velero/ac-iamserviceaccount-velero.yaml
else
    echo ">>> account id is empty!!!"
    exit
fi

# Velero
eksctl create iamserviceaccount -f values/velero/ac-iamserviceaccount-velero.yaml -p ${PROFILE} --approve