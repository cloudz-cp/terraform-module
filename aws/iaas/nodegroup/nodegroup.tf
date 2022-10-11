variable nodegroup {}
variable vpc {}
variable eks {}
variable aws_credentials {}
variable cluster_name{}

module "nodegroup" {
    source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"

    for_each = var.nodegroup

    cluster_name = var.cluster_name
    vpc_id       = var.vpc.vpc_id
    subnet_ids   = [var.vpc.private_subnets[0]]

    cluster_primary_security_group_id = var.eks.cluster_primary_security_group_id
    cluster_security_group_id         = var.eks.node_security_group_id

    desired_size    = each.value["pool_size"]
    max_size        = each.value["max_size"]
    min_size        = each.value["min_size"]
  

    instance_types    = each.value["machine_type"]
    disk_size         = each.value["disk_size"]
    ami_type          = each.value["ami_type"]
    labels            = each.value["node_labels"]
    tags              = each.value["node_tags"]
}

resource "null_resource" "update_node_label_mgmt" {
  depends_on = [module.nodegroup]

  provisioner "local-exec" {
    command = <<EOT
      export AWS_ACCESS_KEY_ID=${var.aws_credentials.aws_access_key}
      export AWS_SECRET_ACCESS_KEY=${var.aws_credentials.aws_secret_key}
      export AWS_SESSION_TOKEN=${var.aws_credentials.aws_session_token}

      aws eks update-kubeconfig --name ${module.nodegroup.cluster_name}
      #kubectl label node -l role="management" node-role.kubernetes.io/management="management" --overwrite
    EOT
  }
}
