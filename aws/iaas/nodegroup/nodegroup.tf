variable nodegroup {}
variable vpc {}
variable eks {}
variable subnets {}
variable aws_credentials {}
variable cluster_name{}

locals {
    eks_subnets = compact([for key, subnet in var.subnets : subnet.is_eks_subnet == true ? key : ""])
}

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

/*data "aws_security_groups" "select_cluster" {
    filter {
        name   = "vpc-id"
        values = [var.vpc.vpc_id]
    }
    filter {
        name = "aws:eks:cluster-name"
        values = [var.cluster_name]
    }
}*/

module "nodegroup" {
    source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
    version = "18.26.6"
    
    for_each = var.nodegroup
    cluster_name = var.cluster_name
    name         = each.key
    vpc_id       = var.vpc.vpc_id
    
    subnet_ids      = data.aws_subnets.eks_subnets.ids

    cluster_primary_security_group_id = var.eks.cluster_primary_security_group_id
    cluster_security_group_id         = var.eks.node_security_group_id

    desired_size      = each.value["pool_size"]
    max_size          = each.value["max_size"]
    min_size          = each.value["min_size"]
  
    instance_types    = each.value["machine_type"]
    disk_size         = each.value["disk_size"]
    ami_type          = each.value["ami_type"]
    labels            = each.value["node_labels"]
    tags              = each.value["node_tags"]

    iam_role_additional_policies = [
        "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess",
        "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    ]

}

resource "null_resource" "node_labels" {
    depends_on = [module.nodegroup]
    for_each = var.nodegroup

    provisioner "local-exec" {
        command = <<EOT
        export AWS_ACCESS_KEY_ID=${var.aws_credentials.aws_access_key}
        export AWS_SECRET_ACCESS_KEY=${var.aws_credentials.aws_secret_key}
        export AWS_SESSION_TOKEN=${var.aws_credentials.aws_session_token}

        aws eks update-kubeconfig --name ${var.cluster_name}
        kubectl label node -l role="${each.value["node_role"]}" node-role.kubernetes.io/${each.value["node_role"]}="${each.value["node_role"]}" --overwrite
        EOT
    }
}
