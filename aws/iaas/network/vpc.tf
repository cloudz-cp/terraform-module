module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.2"

  name = var.vpc.vpc_name

  cidr                  = var.vpc.vpc_cidr
  secondary_cidr_blocks = var.vpc.vpc_secondary_cidr
  azs                   = var.azs

  enable_nat_gateway    = var.vpc.enable_nat_gateway
  single_nat_gateway    = var.vpc.single_nat_gateway
  enable_dns_hostnames  = true

  #tags = local.common.tags
}
