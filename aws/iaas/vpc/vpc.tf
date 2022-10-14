variable vpc {}
variable cluster_name {}
variable azs {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.2"

  name = var.vpc.vpc_name

  cidr                  = var.vpc.vpc_cidr
  secondary_cidr_blocks = var.vpc.vpc_secondary_cidr
  azs                   = var.azs

  private_subnets       = var.vpc.private_subnets
  public_subnets        = var.vpc.public_subnets
  intra_subnets         = var.vpc.vpc_secondary_subnets

  enable_nat_gateway    = var.vpc.enable_nat_gateway
  single_nat_gateway    = var.vpc.single_nat_gateway
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
