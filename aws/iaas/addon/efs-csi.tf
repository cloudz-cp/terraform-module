locals {
    fs_name_list =  keys(aws_efs_file_system.filesystem)    
}

module "efs_csi_irsa_role" {
    source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
    count = var.addon_selected.efs ? 1 :0
    role_name = format("%s-efs-csi", var.eks.cluster_id)
    attach_efs_csi_policy = true

    oidc_providers = {
        main = {
        provider_arn               = var.eks.oidc_provider_arn
        namespace_service_accounts = ["kube-system:efs-csi-controller-sa"]
        }
    }
}

resource "kubernetes_service_account" "efs_csi_controller_sa" {
    count = var.addon_selected.efs ? 1 : 0
    metadata {
        name = "efs-csi-controller-sa"
        namespace = "kube-system"
        annotations = {
            "eks.amazonaws.com/role-arn" = module.efs_csi_irsa_role[0].iam_role_arn
        }
    }
}

resource "helm_release" "aws_efs_csi_driver" {
    count = var.addon_selected.efs ? 1 : 0

    name      = "aws-efs-csi-driver"
    namespace = "kube-system"

    repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver"
    chart      = "aws-efs-csi-driver"
    version    = "2.2.7"

    values = [
        "${file("helm_values/efs.yaml")}"
    ]

    set {
        name  = "controller.serviceAccount.name"
        value = kubernetes_service_account.efs_csi_controller_sa[0].metadata[0].name
    }

    ///// fill the filesystemId in efs.yaml 
    dynamic "set" {
        for_each = aws_efs_file_system.filesystem
        content {            
            name  = "storageClasses[${index("${local.fs_name_list}", "${set.key}")}].parameters.fileSystemId"
            value = aws_efs_file_system.filesystem[set.key].id
        }
    } 

    dynamic "set" {
        for_each = aws_efs_file_system.filesystem
        content {            
            name  = "storageClasses[${sum("${tolist(["${index("${local.fs_name_list}", "${set.key}")}", "${length("${local.fs_name_list}")}"])}")}].parameters.fileSystemId"
            value = aws_efs_file_system.filesystem[set.key].id
        }
    }
    
    ///// fill the storageClass name in efs.yaml  
    dynamic "set" {
        for_each = aws_efs_file_system.filesystem
        content {            
            name  = "storageClasses[${index("${local.fs_name_list}", "${set.key}")}].name"
            value = format("%s", set.key)
        }
    } 

    dynamic "set" {
        for_each = aws_efs_file_system.filesystem
        content {            
            name  = "storageClasses[${sum("${tolist(["${index("${local.fs_name_list}", "${set.key}")}", "${length("${local.fs_name_list}")}"])}")}].name"
            value = format("%s-retain", set.key)
        }
    }

    /*set {
        name  = "storageClasses[0].parameters.fileSystemId"
        value = aws_efs_access_point.aws_efs_access_point[0].file_system_id
    }

    set {
        name  = "storageClasses[1].parameters.fileSystemId"
        value = aws_efs_access_point.aws_efs_access_point[0].file_system_id
    }*/
}


