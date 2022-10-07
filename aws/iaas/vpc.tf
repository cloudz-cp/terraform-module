module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"


  version = "3.14.2"

  name = local.vpc_name

  cidr = var.vpc_cidr_block
  secondary_cidr_blocks = ["144.64.0.0/21"]

  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  intra_subnets = ["144.64.0.0/23", "144.64.2.0/23"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }

  tags = local.common.tags


}
