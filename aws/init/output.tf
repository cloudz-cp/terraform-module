output "efs_count" {
    value = local.efs_count
}

output "s3_count" {
    value = local.s3_count
}

output "public_lb_count" {
    value = local.public_lb_subnet_count
}
output "private_lb_count"{
    value = local.private_lb_subnet_count
}