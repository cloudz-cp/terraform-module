variable nodegroup {}
variable vpc {}
variable eks {}
variable aws_credentials {}
variable eks_subnet_ids {}
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
    /*depends_on = [
      aws_security_group.ssh
    ]*/
    source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
    version = "18.30.2"
    
    for_each    = var.nodegroup
    cluster_name = var.eks.cluster_id
    name         = each.key
    vpc_id       = var.vpc.vpc_id
    iam_role_arn = aws_iam_role.eks_ng_role.arn

    create_security_group = false
    subnet_ids      = var.eks_subnet_ids

    cluster_primary_security_group_id = var.eks.cluster_primary_security_group_id
    #cluster_security_group_id         = var.eks.node_security_group_id

    desired_size      = each.value["pool_size"]
    max_size          = each.value["max_size"]
    min_size          = each.value["min_size"]
  
    instance_types    = each.value["machine_type"]
    disk_size         = each.value["disk_size"]
    ami_type          = each.value["ami_type"]
    labels            = merge(each.value["node_labels"], tomap({ role = each.value["node_role"]}))
    tags              = each.value["node_tags"]
    

    create_iam_role = false


    // 지원시 remote_access 의 value와 상관없이 nodegroup을 매번 다시 생성함 

    /*remote_access =  { 
        ec2_ssh_key = each.value["ssh"].public_key 
        source_security_group_ids = each.value["ssh"].public_key != "" ? aws_security_group.ssh.*.id : []
    }*/

    /*remote_access = each.value["ssh"].public_key != "" ? { 
        ec2_ssh_key = each.value["ssh"].public_key 
        source_security_group_ids = aws_security_group.ssh.*.id
    } : {
        ec2_ssh_key = null 
        source_security_group_ids = []
    }*/

    vpc_security_group_ids = [var.eks.node_security_group_id]
    
}

resource "aws_iam_role" "eks_ng_role" {
  name = "${var.eks.cluster_id}-eks-ng-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "ng_worker_policy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    role       = aws_iam_role.eks_ng_role.name
}

resource "aws_iam_role_policy_attachment" "ng_cni_policy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    role       = aws_iam_role.eks_ng_role.name
}

resource "aws_iam_role_policy_attachment" "ng_registry_policy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    role       = aws_iam_role.eks_ng_role.name
}


resource "aws_iam_role_policy_attachment" "ng_lb_access" {
    policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
    role        = aws_iam_role.eks_ng_role.name
}

resource "aws_iam_role_policy_attachment" "ng_s3_access" {
    policy_arn  = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    role        = aws_iam_role.eks_ng_role.name
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
        export AWS_DEFAULT_REGION=${var.aws_credentials.aws_region}

        aws eks update-kubeconfig --name ${var.eks.cluster_id} --kubeconfig ${abspath(path.root)}/kube-config
        export KUBECONFIG=${abspath(path.root)}/kube-config

        kubectl label node -l role="${each.value["node_role"]}" node-role.kubernetes.io/${each.value["node_role"]}="${each.value["node_role"]}" --overwrite
        EOT
    }
}


resource "aws_security_group" "ssh" {
    name        = "${var.eks.cluster_id}-eks-nodegroup-ssh-sg"
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
        Name = "${var.eks.cluster_id}-eks-nodegroup-ssh-sg"
    }
}

resource "aws_eks_addon" "coredns" {
    depends_on = [
      module.nodegroup
    ]
    cluster_name = var.eks.cluster_id
    addon_name   = "coredns"
    resolve_conflicts = "OVERWRITE"
}


resource "null_resource" "node_start" {
    depends_on = [aws_iam_role.eks_ng_role]
    triggers = {
        always_run = "${timestamp()}"
    }
  
    provisioner "local-exec" {
      command = "echo EKS - Nodegroup Installation : Start >> logs/process.log"
    }
}


resource "null_resource" "node_completed" {
  depends_on = [module.nodegroup]
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
  command = "echo EKS - Nodegroup Installation : Completed >> logs/process.log"
  }
}