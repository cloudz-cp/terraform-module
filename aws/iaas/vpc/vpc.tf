module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"

  variable vpc_name {}
  variable private_subnets {}
  variable public_subnets {}
  variable cluster_name {}
  variable vpc_cidr_block {}
  variable vpc_secondary_cidr {}
  variable vpc_secondary_subnets {}
  
  version = "3.14.2"

  name = local.vpc_name

  cidr = var.vpc_cidr_block
  #secondary_cidr_blocks = ["144.64.0.0/21"]
  secondary_cidr_blocks = var.vpc_secondary_cidr
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  intra_subnets = var.vpc_secondary_subnets
  #intra_subnets = ["144.64.0.0/23", "144.64.2.0/23"]

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

  tags = local.common.tags
}
