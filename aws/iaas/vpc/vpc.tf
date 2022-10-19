variable vpc {}
variable cluster_name {}
variable azs {}

locals {
    vpc_name    = var.vpc_name == "" ? format("%s-eks-vpc", var.cluster_name) : var.cluster_name
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.2"

  name = local.vpc.vpc_name

  cidr                  = var.vpc.vpc_cidr
  secondary_cidr_blocks = var.vpc.vpc_secondary_cidr
  azs                   = var.azs

  enable_nat_gateway    = var.vpc.enable_nat_gateway
  single_nat_gateway    = var.vpc.single_nat_gateway
  enable_dns_support    = true
  enable_dns_hostnames  = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }

  #tags = local.common.tags
}
