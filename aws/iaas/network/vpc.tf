module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.2"

  name = var.vpc.vpc_name

  cidr                  = var.vpc.vpc_cidr
  secondary_cidr_blocks = var.vpc.vpc_secondary_cidr
  azs                   = var.azs
  
  //subnet resource에서 natgw 및 routing 처리 
  enable_nat_gateway    = false //var.vpc.enable_nat_gateway
  single_nat_gateway    = false //var.vpc.single_nat_gateway
  enable_dns_hostnames  = true

  #tags = local.common.tags
}


resource "null_resource" "vpc_start" {
    provisioner "local-exec" {
        command = "echo Network - VPC Installation  : Start  >> logs/process.log"
    }
}


resource "null_resource" "vpc_completed" {
    depends_on = [module.vpc]

    provisioner "local-exec" {
        command = "echo Network - VPC Installation  : Completed  >> logs/process.log"
    }
}