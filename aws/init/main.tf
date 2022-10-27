variable efs {}

locals {
    efs_count = length(var.efs)
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