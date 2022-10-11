variable "cluster_name" {}  
variable "cluster_version" {}
variable "vpc" {}
variable azs {}
variable aws_credentials {}



module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.26.6"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc.vpc_id
  subnet_ids = var.vpc.private_subnets

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  cluster_addons = {
    kube-proxy = {
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }
 
  node_security_group_additional_rules = {
    albc_webhook_ingress = {
      type                          = "ingress"
      protocol                      = "tcp"
      from_port                     = 9443
      to_port                       = 9443
      source_cluster_security_group = true
      description                   = "Allow access from control plane to webhook port of AWS load balancer controller"
    }
  }

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

  #tags = local.common.tags
}

resource "null_resource" "eniconfig" {
  depends_on = [module.eks]

  triggers = {
    always_run = "${timestamp()}"
  }
  
  provisioner "local-exec" {
    command = <<EOT
      az1=$(echo ${var.azs[0]})
      az2=$(echo ${var.azs[1]})
      sub1=$(echo ${var.vpc.intra_subnets[0]})
      sub2=$(echo ${var.vpc.intra_subnets[1]})
      sg=$(echo ${module.eks.node_security_group_id})
      cluster=$(echo ${var.cluster_name})

      echo $az1 $az2 $sub1 $sub2 $sg $cluster
      
      export AWS_ACCESS_KEY_ID=${var.aws_credentials.aws_access_key}
      export AWS_SECRET_ACCESS_KEY=${var.aws_credentials.aws_secret_key}
      export AWS_SESSION_TOKEN=${var.aws_credentials.aws_session_token}
      export AWS_ROLE_ARN=${var.aws_credentials.aws_role_arn}

      aws eks update-kubeconfig --name $cluster
      kubectl set env daemonset aws-node -n kube-system AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true
      kubectl set env daemonset aws-node -n kube-system ENI_CONFIG_LABEL_DEF=topology.kubernetes.io/zone
      ./setup_eniconfig.sh $az1 $sub1 $sg
      ./setup_eniconfig.sh $az2 $sub2 $sg
  EOT
}
}

resource "aws_eks_addon" "coredns" {
  depends_on = [null_resource.eniconfig]

  cluster_name = module.eks.cluster_id
  addon_name   = "coredns"
  resolve_conflicts = "OVERWRITE"
}
