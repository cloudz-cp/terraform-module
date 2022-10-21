variable nodegroup {}
variable vpc {}
variable eks {}
variable subnets {}
variable aws_credentials {}
variable eks{}

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
    cluster_name = var.eks.cluster_name
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
    labels            = merge(each.value["node_labels"], tomap({ role = each.value["node_role"]}))
    tags              = each.value["node_tags"]

    dynamic "remote_access" {
        for_each = each.value["ssh"] != "" ? [{ec2_ssh_key = each.value["ssh"].public_key}] : []

        content {
            ec2_ssh_key               = remote_access.value["ec2_ssh_key"]
            source_security_group_ids = aws_security_group.nodegroup.*.id
        }
    }

    iam_role_additional_policies = concat([
        "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess",
        "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    ], each.value["attach_policy"])

}

resource "null_resource" "node_labels" {
    depends_on = [module.nodegroup]
    triggers = {
        always_run = "${timestamp()}"
    }

    for_each = var.nodegroup

    provisioner "local-exec" {
        command = <<EOT
        export AWS_ACCESS_KEY_ID=${var.aws_credentials.aws_access_key}
        export AWS_SECRET_ACCESS_KEY=${var.aws_credentials.aws_secret_key}
        export AWS_SESSION_TOKEN=${var.aws_credentials.aws_session_token}

        aws eks update-kubeconfig --name ${var.eks.cluster_name}
        kubectl label node -l role="${each.value["node_role"]}" node-role.kubernetes.io/${each.value["node_role"]}="${each.value["node_role"]}" --overwrite
        EOT
    }
}


resource "aws_security_group" "ssh" {
    count = var.nodegroup.ssh != "" ? 1 : 0 
    name        = "${var.eks.cluster_name}-eks-nodegroup-ssh-sg"
    description = "Security group to access SSH"
    vpc_id      = var.vpc.vpc_id 

    ingress {
        from_port               = 22
        to_port                 = 22
        protocol                = "tcp"
        cidr_blocks             = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.eks.cluster_name}-eks-nodegroup-ssh-sg"
    }
}