#!/bin/bash

PROFILE=$1
CLUSTER_NAME=$2
REGION=$3
VELERO_BUCKET=$4


. ./env.properties

export AWS_PROFILE=$PROFILE
export AWS_REGION=$REGION

VELERO_BUCKET=${CLUSTER_NAME}-velero

aws s3api create-bucket \
--bucket ${VELERO_BUCKET} \
--create-bucket-configuration LocationConstraint=${REGION} \

aws s3api put-public-access-block \
--bucket ${VELERO_BUCKET} \
--public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true\