#!/bin/sh

AZ=$1
SUBNET=$2
SG=$3

cat <<EOF > eniconfig.yaml
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata:
  name: ${AZ}
spec:
  subnet: ${SUBNET}
  securityGroups:
    - ${SG}
EOF

kubectl apply -f eniconfig.yaml
