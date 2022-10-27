variable vpc {}
variable subnets {}
variable aws_credentials {}
variable eks {}
variable azs {}

locals {
    pod_subnet_az = {for key, subnet in var.subnets : key => subnet.az if subnet.subnet_type == "pod"}
    pod_subnet_keys = keys(local.pod_subnet_az)
}

data "aws_subnet" "pod_subnets" {
    for_each    = local.pod_subnet_az
    
    filter {
        name    = "vpc-id"
        values  = [var.vpc.vpc_id]
    }

    filter {
        name = "tag:Name"
        values = [each.key]
    }
}

resource "null_resource" "eniconfig" {
  triggers = {
    always_run = "${timestamp()}"
  }
  
  provisioner "local-exec" {
    command = <<EOT
        az1=$(echo ${local.pod_subnet_az[local.pod_subnet_keys[0]]})
        az2=$(echo ${local.pod_subnet_az[local.pod_subnet_keys[1]]})
        sub1=$(echo ${data.aws_subnet.pod_subnets[local.pod_subnet_keys[0]].id})
        sub2=$(echo ${data.aws_subnet.pod_subnets[local.pod_subnet_keys[1]].id})
        sg=$(echo ${var.eks.cluster_primary_security_group_id})
        cluster=$(echo ${var.eks.cluster_id})

        echo $az1 $az2 $sub1 $sub2 $sg $cluster
        
        export AWS_ACCESS_KEY_ID=${var.aws_credentials.aws_access_key}
        export AWS_SECRET_ACCESS_KEY=${var.aws_credentials.aws_secret_key}
        export AWS_SESSION_TOKEN=${var.aws_credentials.aws_session_token}
        export AWS_ROLE_ARN=${var.aws_credentials.aws_role_arn}

        aws eks update-kubeconfig --name $cluster
        kubectl set env daemonset aws-node -n kube-system AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true
        kubectl set env daemonset aws-node -n kube-system ENI_CONFIG_LABEL_DEF=topology.kubernetes.io/zone
        echo "" > ${path.module}/eni-config/eniconfig.yaml
        ${path.module}/setup_eniconfig.sh $az1 $sub1 $sg ${path.module}
        ${path.module}/setup_eniconfig.sh $az2 $sub2 $sg ${path.module}
        kubectl apply -f ${path.module}/eni-config/eniconfig.yaml
  EOT
}
}

