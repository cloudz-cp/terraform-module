variable cluster_name {}  
variable cluster_version {}
variable vpc {}
variable azs {}
variable aws_credentials {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.26.6"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id          = var.vpc.vpc_id
  subnet_ids      = var.vpc.private_subnets

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


