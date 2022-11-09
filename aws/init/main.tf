variable efs {}
variable s3 {}
variable subnets{}
variable predefined_subnet{}

locals {
    efs_count = length(var.efs)
    s3_count = length(var.s3)+1

    public_lb_subnet_count = length(var.predefined_subnet.public_lb_subnet_ids) > 0 ? length(var.predefined_subnet.public_lb_subnet_ids) : length(compact([for key, subnet in var.subnets : subnet.subnet_type == "lb" && subnet.is_public ? key : ""]))
    private_lb_subnet_count = length(var.predefined_subnet.private_lb_subnet_ids) > 0 ? length(var.predefined_subnet.private_lb_subnet_ids) : length(compact([for key, subnet in var.subnets : subnet.subnet_type == "lb" && !subnet.is_public ? key : ""]))
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


resource "null_resource" "log_initializer" {
    provisioner "local-exec" {
        command = "echo ZCP Cluster Provisioning Start!! > logs/process.log"
    }
}
