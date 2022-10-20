variable cluster_name {}  
variable aws_credentials {}



resource "null_resource" "create-velero-policy" {
  triggers = {
    always_run = "${timestamp()}"
  }
  
  provisioner "local-exec" {
    command = "${path.module}/velero/create-velero-policy.sh$var.profile $var.cluster_name"
  }
}


resource "null_resource" "create-velero-iamserviceaccounts" {
  triggers = {
    always_run = "${timestamp()}"
  }
  
  provisioner "local-exec" {
    command = "${path.module}/velero/create-velero-iamserviceaccounts.sh $var.profile $var.cluster_name $var.account_id "
  }
}

resource "null_resource" "create-velero-s3" {
  triggers = {
    always_run = "${timestamp()}"
  }
  
  provisioner "local-exec" {
    command = "${path.module}/velero/create-velero-s3.sh var.profile $var.cluster_name $var.aws_credentials.region $velero_bucket "
  }
}

resource "null_resource" "create-velero-schedule" {
  triggers = {
    always_run = "${timestamp()}"
  }
  
  provisioner "local-exec" {
    command = <<EOT
    
        # 매일 새벽 2시에 Backup이 수행되며, Backup본 만료 기간은 30일로 설정함
        velero schedule create all-daily --schedule="0 2 * * *" --ttl 720h0m0s

        EOT
    }
}

resource "helm_release" "vmware-tanzu" {
  name      = "velero"
  namespace = "velero"

  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  version    = "2.30.1"

  values     = [
    "${file("./values/velero.yaml")}"
  ]

  set {
    name  = "configuration.provider"
    value = aws
  }

  set {
    name  = "configuration.backupStorageLocation.bucket"
    value = ${var.cluster_name}-velero 
  }

    set {
    name  = "configuration.backupStorageLocation.prefix"
    value = default
  }

    set {
    name  = "configuration.backupStorageLocation.config.region"
    value = ${var.aws_credentials.aws_region}
  }

    set {
    name  = "serviceAccount.server.create"
    value = false
  }

    set {
    name  = "serviceAccount.server.name"
    value = velero-server
  }


    set {
    name  = "kubectl.image.repository"
    value = v2-zcr.cloudzcp.io/cloudzcp-public/bitnami/kubectl
  }

    set {
    name  = "initContainers[0].image"
    value = v2-zcr.cloudzcp.io/cloudzcp-public/velero/velero-plugin-for-aws:v1.5.0 
  }

    set {
    name  = "image.repository"
    value = v2-zcr.cloudzcp.io/cloudzcp-public/velero/velero 
  }

}