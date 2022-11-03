variable efs {}
variable s3 {}

locals {
    efs_count = length(var.efs)
    s3_count = length(var.s3)+1
}

resource "null_resource" "init" {
    triggers = {
        always_run = "${timestamp()}"
    }
    provisioner "local-exec" {
        command = <<EOT
        ${path.module}/file_generator.sh ${local.efs_count} helm_values
    EOT
    }
}