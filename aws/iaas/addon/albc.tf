/* Install Guide
 * https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/deploy/installation/
*/

# https://github.com/terraform-aws-modules/terraform-aws-iam/blob/9210e6c6dc2bbd00065bc6f9212d04a0f49adec2/examples/iam-role-for-service-accounts-eks/main.tf#L184

module "albc_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
    count = var.addon_selected.albc ? 1 : 0

  role_name                      = format("%s-aws-load-balancer-controller", var.eks.cluster_id)
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = var.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller-sa"]
    }
  }
}

resource "kubernetes_service_account" "aws_load_balancer_controller_sa" {
    count = var.addon_selected.albc ? 1 : 0
    metadata {
        name        = "aws-load-balancer-controller-sa"
        namespace   = "kube-system"
        annotations = {
            "eks.amazonaws.com/role-arn" = module.albc_irsa_role[0].iam_role_arn
        }
    }
}
/*
resource "null_resource" "albc-controller-sa" {
    depends_on = [
        module.albc_irsa_role
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
            eks.amazonaws.com/role-arn: ${module.albc_irsa_role[0].iam_role_arn}
        name: aws-load-balancer-controller-sa
        namespace: kube-system
        EOF
        EOT
    } 
}*/

resource "helm_release" "aws_load_balancer_controller" {
    count = var.addon_selected.albc ? 1 : 0
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    repository = "https://aws.github.io/eks-charts"
    chart      = "aws-load-balancer-controller"
    version    = "1.4.4"

    values     = [
        "${file("helm_values/albc.yaml")}"
    ]

    set {
        name  = "clusterName"
        value = var.eks.cluster_id
    }

    set {
        name  = "serviceAccount.name"
        value = "aws-load-balancer-controller-sa"
    }
}

resource "null_resource" "public_lb_tags" {
    triggers = {
        always_run = "${timestamp()}"
    }
    count = var.public_lb_count
    provisioner "local-exec" {
        command = <<EOT
            export AWS_ACCESS_KEY_ID=${var.aws_credentials.aws_access_key}
            export AWS_SECRET_ACCESS_KEY=${var.aws_credentials.aws_secret_key}
            export AWS_SESSION_TOKEN=${var.aws_credentials.aws_session_token}

            aws ec2 create-tags --resources ${var.public_lb_subnet_ids[count.index]} --tags Key=kubernetes.io/role/elb,Value=1
        EOT
    }
}

resource "null_resource" "private_lb_tags" {
    triggers = {
        always_run = "${timestamp()}"
    }
    count = var.private_lb_count
    provisioner "local-exec" {
        command = <<EOT
            export AWS_ACCESS_KEY_ID=${var.aws_credentials.aws_access_key}
            export AWS_SECRET_ACCESS_KEY=${var.aws_credentials.aws_secret_key}
            export AWS_SESSION_TOKEN=${var.aws_credentials.aws_session_token}

            aws ec2 create-tags --resources ${var.private_lb_subnet_ids[count.index]} --tags Key=kubernetes.io/role/internal-elb,Value=1
        EOT
    }    
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

resource "null_resource" "albc_start" {

    provisioner "local-exec" {
    command = "echo ADD-ON - Aws Load Balancer Controller Installation : Start >> logs/process.log"
    }
}


resource "null_resource" "albc_completed" {

  depends_on = [helm_release.aws_load_balancer_controller]

  provisioner "local-exec" {
  command = "echo ADD-ON - Aws Load Balancer Controller Installation : Completed  >> logs/process.log"
  }
}