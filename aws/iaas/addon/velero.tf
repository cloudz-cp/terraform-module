module "velero_irsa_role"{
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name     = format("%s-velero", var.eks.cluster_id)
  attach_velero_policy = true
  velero_s3_bucket_arns = ["arn:aws:s3:::${format("%s-velero-s3-registry", var.eks.cluster_id)}/*"]

  oidc_providers = {
    main = {
      provider_arn               = var.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:velero-controller-sa"]
    }
  }
}

resource "kubernetes_service_account" "velero_controller_sa" {
  metadata {
    name        = "velero-controller-sa"
    namespace   = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.velero_irsa_role.iam_role_arn
    }
  }
}


resource "helm_release" "vmware-tanzu2" {
  name      = "velero"
  namespace = "kube-system"

  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  version    = "2.30.1"
  values     = [
        "${file("helm_values/velero.yaml")}"

  ]

  set {
    name  = "configuration.provider"
    value = "aws"
  }

  set {
    name  = "configuration.backupStorageLocation.bucket"
    value = format("%s-velero-s3-registry", var.eks.cluster_id)
  }

  set {
    name  = "configuration.backupStorageLocation.prefix"
    value = "default"
  }

  set {
    name  = "configuration.backupStorageLocation.config.region"
    value = var.aws_credentials.aws_region
  }

  set {
    name  = "serviceAccount.server.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.server.name"
    value = kubernetes_service_account.velero_controller_sa.metadata[0].name
  }

  set {
    name  = "kubectl.image.repository"
    value = "v2-zcr.cloudzcp.io/cloudzcp-public/bitnami/kubectl"
  }
  set {
    name  = "initContainers[0].image"
    value = "v2-zcr.cloudzcp.io/cloudzcp-public/velero/velero-plugin-for-aws:v1.5.0"
  }


  set {
    name  = "image.repository"
    value = "v2-zcr.cloudzcp.io/cloudzcp-public/velero/velero"
  }

}



