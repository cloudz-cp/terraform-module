locals {
    fs_name_list =  keys(aws_efs_file_system.filesystem)    
}

module "efs_csi_irsa_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "efs-csi"
  attach_efs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
    }
  }
}

resource "kubernetes_service_account" "efs_csi_controller_sa" {
  metadata {
    name = "efs-csi-controller-sa"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.efs_csi_irsa_role.iam_role_arn
    }
  }
}
/*
resource "helm_release" "aws_efs_csi_driver" {
    name      = "aws-efs-csi-driver"
    namespace = "kube-system"

    repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver"
    chart      = "aws-efs-csi-driver"
    version    = "2.2.7"

    values = [
        "${file("${path.module}/values/efs.yaml")}"
    ]

    set {
        name  = "controller.serviceAccount.name"
        value = kubernetes_service_account.efs_csi_controller_sa.metadata[0].name
    }

    dynamic "set" {
        for_each = aws_efs_file_system.filesystem
        content {            
            name  = "storageClasses[${index("${local.fs_name_list}, ${set.key}") * 2}].parameters.fileSystemId"
            value = set.value
        }
        content {            
            name  = "storageClasses[${index("${local.fs_name_list}, ${set.key}") * 2 + 1}].parameters.fileSystemId"
            value = set.value
        }

    }  
  set {
    name  = "storageClasses[0].parameters.fileSystemId"
    value = aws_efs_access_point.aws_efs_access_point[0].file_system_id
  }

  set {
    name  = "storageClasses[1].parameters.fileSystemId"
    value = aws_efs_access_point.aws_efs_access_point[0].file_system_id
  }
}*/

locals {
    static_helm_value = <<EOF
nameOverride: ""
fullnameOverride: ""

replicaCount: 2

image:
repository: amazon/aws-efs-csi-driver
tag: "v1.3.6"
pullPolicy: IfNotPresent

sidecars:
livenessProbe:
    image:
    repository: public.ecr.aws/eks-distro/kubernetes-csi/livenessprobe
    tag: v2.2.0-eks-1-18-2
    pullPolicy: IfNotPresent
    resources: {}
nodeDriverRegistrar:
    image:
    repository: public.ecr.aws/eks-distro/kubernetes-csi/node-driver-registrar
    tag: v2.1.0-eks-1-18-2
    pullPolicy: IfNotPresent
    resources: {}
csiProvisioner:
    image:
    repository: public.ecr.aws/eks-distro/kubernetes-csi/external-provisioner
    tag: v2.1.1-eks-1-18-2
    pullPolicy: IfNotPresent
    resources: {}

imagePullSecrets: []

## Controller deployment variables

controller:
# Specifies whether a deployment should be created
create: true
# Number for the log level verbosity
logLevel: 2
# If set, add pv/pvc metadata to plugin create requests as parameters.
extraCreateMetadata: true
# Add additional tags to access points
tags:
    {}
    # environment: prod
    # region: us-east-1
# Enable if you want the controller to also delete the
# path on efs when deleteing an access point
deleteAccessPointRootDir: false
podAnnotations: {}
resources:
    {}
    # We usually recommend not to specify default resources and to leave this as a conscious
    # choice for the user. This also increases chances charts run on environments with little
    # resources, such as Minikube. If you do want to specify resources, uncomment the following
    # lines, adjust them as necessary, and remove the curly braces after 'resources:'.
    # limits:
    #   cpu: 100m
    #   memory: 128Mi
    # requests:
    #   cpu: 100m
    #   memory: 128Mi
nodeSelector: {}
tolerations: []
affinity: {}
# Specifies whether a service account should be created
serviceAccount:
    create: false
    name: efs-csi-controller-sa
    annotations: {}
healthPort: 9909

## Node daemonset variables

node:
# Number for the log level verbosity
logLevel: 2
hostAliases:
    {}
    # For cross VPC EFS, you need to poison or overwrite the DNS for the efs volume as per
    # https://docs.aws.amazon.com/efs/latest/ug/efs-different-vpc.html#wt6-efs-utils-step3
    # implementing the suggested solution found here:
    # https://github.com/kubernetes-sigs/aws-efs-csi-driver/issues/240#issuecomment-676849346
    # EFS Vol ID, IP, Region
    # "fs-01234567":
    #   ip: 10.10.2.2
    #   region: us-east-2
dnsPolicy: ClusterFirst
dnsConfig:
    {}
    # Example config which uses the AWS nameservers
    # dnsPolicy: "None"
    # dnsConfig:
    #   nameservers:
    #     - 169.254.169.253
podAnnotations: {}
resources:
    {}
    # limits:
    #   cpu: 100m
    #   memory: 128Mi
    # requests:
    #   cpu: 100m
    #   memory: 128Mi
nodeSelector: {}
tolerations:
    - operator: Exists
# Specifies whether a service account should be created
serviceAccount:
    create: true
    name: efs-csi-node-sa
    annotations: {}
    ## Enable if EKS IAM for SA is used
    #  eks.amazonaws.com/role-arn: arn:aws:iam::111122223333:role/efs-csi-role
healthPort: 9809
    EOF

}

resource "null_resource" "create-efs-yaml" {
    provisioner "local-exec" {
        command = "cat ${local.static_helm_value} > ${path.module}/values/efs.yaml"        
    }
}
