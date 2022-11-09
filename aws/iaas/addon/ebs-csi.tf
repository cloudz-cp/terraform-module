module "ebs_csi_irsa_role" {
    source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
    count = var.addon_selected.ebs ? 1 : 0
    role_name = format("%s-ebs-csi", var.eks.cluster_id)
    attach_ebs_csi_policy = true

    oidc_providers = {
    main = {
            provider_arn               = var.eks.oidc_provider_arn
            namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
        }
    }
}

resource "kubernetes_service_account" "ebs_csi_controller_sa" {
    count = var.addon_selected.ebs ? 1 : 0

    metadata {
        name = "ebs-csi-controller-sa"
        namespace = "kube-system"
        annotations = {
            "eks.amazonaws.com/role-arn" = module.ebs_csi_irsa_role[0].iam_role_arn
        }
    }
}
/*
resource "null_resource" "ebs-controller-sa" {
    depends_on = [
        module.ebs_csi_irsa_role
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
            eks.amazonaws.com/role-arn: ${module.ebs_csi_irsa_role[0].iam_role_arn}
        name: ebs-csi-controller-sa
        namespace: kube-system
        EOF
        EOT
    } 
}*/

resource "helm_release" "aws_ebs_csi_driver" {
    count = var.addon_selected.ebs ? 1 : 0

    name      = "aws-ebs-csi-driver"
    namespace = "kube-system"

    repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
    chart      = "aws-ebs-csi-driver"
    version    = "2.10.0"

    values = [
        "${file("helm_values/ebs.yaml")}"
    ]

    set {
        name  = "controller.serviceAccount.name"
        value = "ebs-csi-controller-sa"
    }
}


resource "null_resource" "ebs_start" {
  provisioner "local-exec" {
  command = "echo ADD-ON - Aws EBS Csi Driver Installation : Start >> logs/process.log"
  }
}


resource "null_resource" "ebs_completed" {

  depends_on = [helm_release.aws_ebs_csi_driver]

  provisioner "local-exec" {
  command = "echo ADD-ON - Aws EBS Csi Driver Installation : Completed  >> logs/process.log"
  }
}