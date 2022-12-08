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

/*resource "null_resource" "efs-controller-sa" {
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
            eks.amazonaws.com/role-arn: ${module.efs_csi_irsa_role[0].iam_role_arn}
        name: efs-csi-controller-sa
        namespace: kube-system
        EOF
        EOT
    } 
}*/

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
        value = "efs-csi-controller-sa"
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


resource "null_resource" "efs_start" {
    triggers = {
        always_run = "${timestamp()}"
    }
    provisioner "local-exec" {
    command = "echo ADD-ON - EFS Installation : Start >> logs/process.log"
  }
}


resource "null_resource" "efs_completed" {
    triggers = {
        always_run = "${timestamp()}"
    }
  depends_on = [aws_efs_backup_policy.backup_policy]

  provisioner "local-exec" {
  command = "echo ADD-ON - EFS Installation : Completed  >> logs/process.log"
  }
}