#!/bin/bash


PROFILE=$1
CLUSTER_NAME=$2

# replace variables
set -e

if [ "x${CLUSTER_NAME}" != "x" ]
then
    echo "cluster name is ${CLUSTER_NAME}"
    sed 's/VAR_CLUSTER_NAME/'"${CLUSTER_NAME}"'/g' velero/velero-policy.json > velero/cn-velero-policy.json
else
    echo ">>> cluster name is empty!!!"
    exit
fi


export AWS_PROFILE=$PROFILE

aws iam create-policy \
--policy-name ${CLUSTER_NAME}-velero-policy \
--policy-document file://velero/cn-velero-policy.json