module "velero_irsa_role"{
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name     = format("%s-velero", var.eks.cluster_id)
  attach_velero_policy = true
  velero_s3_bucket_arns = ["arn:aws:s3:::${format("%s-velero-s3-registry", var.eks.cluster_id)}"]

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
}/*
resource "null_resource" "velero-controller-sa" {
    depends_on = [
        module.efs_csi_irsa_role
    ]
    provisioner "local-exec" {
        command = <<EOT
        export AWS_ACCESS_KEY_ID=${var.aws_credentials.aws_access_key}
        export AWS_SECRET_ACCESS_KEY=${var.aws_credentials.aws_secret_key}
        export AWS_SESSION_TOKEN=${var.aws_credentials.aws_session_token}
        aws eks update-kubeconfig --name ${var.eks.cluster_id}

        cat <<EOF | kubectl apply -f -
        apiVersion: v1
        automountServiceAccountToken: true
        kind: ServiceAccount
        metadata:
        annotations:
            eks.amazonaws.com/role-arn: ${module.velero_irsa_role.iam_role_arn}
        name: velero-controller-sa
        namespace: kube-system
        EOF
        EOT
    } 
}*/


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
    value = "velero-controller-sa"
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

/*resource "kubernetes_manifest" "test" {
    depends_on = [
        helm_release.vmware-tanzu2
    ]
    manifest = {
        "apiVersion" = "velero.io/v1"
        "kind" = "Schedule"
        "metadata" = {
            "name" = "all-daily"
            "namespace" = "kube-system"
        }
        "spec" = {
            "schedule" = "0 2 * * *"
            "template" = {
                "includedNamespaces" = ["*"]
                "ttl" = "720h0m0s"
            }
            "useOwnerReferencesInBackup"= false
        }
    }

    wait {
        fields = {
            "status.phase" = "Enabled"
        }
    }
}*/

resource "null_resource" "velero_started" {

  provisioner "local-exec" {
  command = "echo ADD-ON - Velero Installation : Start >> logs/process.log"
  }
}


resource "null_resource" "velero_completed" {

  depends_on = [helm_release.vmware-tanzu2]

  provisioner "local-exec" {
  command = "echo ADD-ON - Velero Installation : Completed  >> logs/process.log"
  }
}