variable cluster_name {}  
variable vpc {}
variable aws_credentials {}
variable eks {}
variable azs {}

resource "null_resource" "eniconfig" {
  triggers = {
    always_run = "${timestamp()}"
  }
  
  provisioner "local-exec" {
    command = <<EOT
      az1=$(echo ${var.azs[0]})
      az2=$(echo ${var.azs[1]})
      sub1=$(echo ${var.vpc.intra_subnets[0]})
      sub2=$(echo ${var.vpc.intra_subnets[1]})
      sg=$(echo ${var.eks.node_security_group_id})
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

  cluster_name = var.cluster_name
  addon_name   = "coredns"
  resolve_conflicts = "OVERWRITE"
}