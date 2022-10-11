variable vpc_name {}
variable private_subnets {}
variable public_subnets {}
variable cluster_name {}
variable vpc_cidr {}
variable vpc_secondary_cidr {}
variable vpc_secondary_subnets {}
variable azs {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.2"

  name = var.vpc_name

  cidr = var.vpc_cidr
  secondary_cidr_blocks = var.vpc_secondary_cidr
  azs  = var.azs

  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  intra_subnets = var.vpc_secondary_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

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
