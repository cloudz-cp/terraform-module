#!/bin/sh

AZ=$1
SUBNET=$2
SG=$3
ENI_PATH=$4

cat <<EOF >> ${ENI_PATH}/eniconfig.yaml
---
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata:
  name: ${AZ}
spec:
  subnet: ${SUBNET}
  securityGroups:
    - ${SG}
---
EOF