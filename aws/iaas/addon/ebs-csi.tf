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
        value = kubernetes_service_account.ebs_csi_controller_sa[0].metadata[0].name
    }
}