variable eks {}
variable vpc {}
variable azs {}
variable aws_credentials {}
variable eks_subnet_ids {}


locals {
    logkeys = [for k,v in tomap(var.eks.log_type) : k if v == true]
}

resource "aws_iam_role" "cluster" {
  name = "${var.eks.name}-eks-cluster-role"

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
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSVPCResourceController" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
    role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
    count = length(var.eks.attach_policy)
    policy_arn = var.eks.attach_policy[count.index]
    role = aws_iam_role.cluster.name
}


module "eks" {    
    source  = "terraform-aws-modules/eks/aws"
    version = "18.26.6"

    cluster_name    = var.eks.name
    cluster_version = var.eks.version
    iam_role_arn    = aws_iam_role.cluster.arn

    vpc_id          = var.vpc.vpc_id
    subnet_ids      = var.eks_subnet_ids

    cluster_endpoint_private_access = var.eks.private_access
    cluster_endpoint_public_access  = var.eks.public_access
    create_iam_role = false
    create_cloudwatch_log_group = false

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
    //iam_role_additional_policies = ["arn:aws:iam::aws:policy/AmazonEKSClusterPolicy", "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"]
    cluster_enabled_log_types = local.logkeys
    tags = var.eks.tags
}

resource "aws_eks_addon" "vpc-cni" {
    depends_on = [
      module.eks
    ]
    count = var.eks.addon.vpc-cni ? 1 : 0
    cluster_name = var.eks.name
    addon_name   = "vpc-cni"
    resolve_conflicts = "OVERWRITE"
}

resource "aws_eks_addon" "kube-proxy" {
    depends_on = [
      module.eks
    ]
    count = var.eks.addon.kube-proxy ? 1 : 0
    cluster_name = var.eks.name
    addon_name   = "kube-proxy"
    resolve_conflicts = "OVERWRITE"
}
