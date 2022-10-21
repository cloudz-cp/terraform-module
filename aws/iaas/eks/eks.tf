variable cluster_name {}  
variable cluster_version {}
variable eks {}
variable vpc {}
variable azs {}
variable subnets {}
variable aws_credentials {}

locals {
    eks_subnets = compact([for key, subnet in var.subnets : subnet.is_eks_subnet == true ? key : ""])
    pod_subnets = compact([for key, subnet in var.subnets : subnet.is_pod_subnet == true ? key : ""])
}

/*resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-eks-cluster-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster.name
}*/



data "aws_subnets" "eks_subnets" {
    filter {
        name   = "vpc-id"
        values = [var.vpc.vpc_id]
    }
    filter {
        name = "tag:Name"
        values = local.eks_subnets
    }
}

data "aws_subnets" "pod_subnets" {
    filter {
        name   = "vpc-id"
        values = [var.vpc.vpc_id]
    }

    filter {
        name = "tag:Name"
        values = local.eks_subnets
    }
}

module "eks" {    
    /*depends_on = [
        aws_iam_role_policy_attachment.cluster-AmazonEKSClusterPolicy,
        aws_iam_role_policy_attachment.cluster-AmazonEKSServicePolicy    
    ]*/

    source  = "terraform-aws-modules/eks/aws"
    version = "18.26.6"

    cluster_name    = var.eks.name
    cluster_version = var.eks.version
    vpc_id          = var.vpc.vpc_id
    subnet_ids      = data.aws_subnets.eks_subnets.ids

    cluster_endpoint_private_access = var.eks.private_access
    cluster_endpoint_public_access  = var.eks.public_access
    
    /*
    cluster_addons = {
        kube-proxy = {
        resolve_conflicts = "OVERWRITE"
        }
        vpc-cni = {
        resolve_conflicts = "OVERWRITE"
        }
    }*/
    
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

    /*eks_managed_node_group_defaults = {
        ami_type = "AL2_x86_64"
    }*/

    tags = var.eks.tags
}

resource "aws_eks_addon" "vpc-cni" {
    count = var.eks.addon.vpc-cni ? 1 : 0
    cluster_name = var.eks.name
    addon_name   = "vpc-cni"
    resolve_conflicts = "OVERWRITE"
}

resource "aws_eks_addon" "kube-proxy" {
    count = var.eks.addon.kube-proxy ? 1 : 0
    cluster_name = var.eks.name
    addon_name   = "kube-proxy"
    resolve_conflicts = "OVERWRITE"
}