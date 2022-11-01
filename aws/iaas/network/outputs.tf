locals{
    ids =  [for subnet in local.subnets : subnet.id]
    subnet_keys = keys(local.subnets)
}

data "aws_subnets" "eks_subnets" {
    depends_on = [
      aws_subnet.eks
    ]
    filter {
        name   = "vpc-id"
        values = [module.vpc.vpc_id]
    }
    filter {
        name = "tag:Name"
        values = local.eks_subnets
    }
}

data "aws_subnets" "pod_subnets" {
    depends_on = [
      aws_subnet.eks
    ]
    filter {
        name   = "vpc-id"
        values = [module.vpc.vpc_id]
    }

    filter {
        name = "tag:Name"
        values = local.pod_subnets
    }
}
/*
data "aws_subnet" "eks" {
    depends_on = [
      aws_subnet.eks
    ]
    for_each = toset(data.aws_subnets.eks_subnets.ids)
    id       = each.value
}

data "aws_subnet" "pod" {
    depends_on = [
      aws_subnet.eks
    ]
    for_each = toset(data.aws_subnets.pod_subnets.ids)
    id       = each.value
}
*/
output "output" {
    value = module.vpc
}

output "subnet_ids" {
    value = local.subnets
    description = "created all subnet ids"
}

output "eks_subnet_ids" {
    value = compact([for subnet in toset(data.aws_subnets.eks_subnets.ids) : contains(local.ids, subnet) ? subnet : ""])
    description = "eks subnet ids "
}

output "eks_subnet_cidr" {
    value = compact([for subnet in toset(data.aws_subnets.eks_subnets.ids) : contains(local.ids, subnet) ? local.subnets[local.subnet_keys[index(local.ids, subnet)]].cidr_block : ""])
}

output "pod_subnet_ids" {
    value = compact([for subnet in toset(data.aws_subnets.pod_subnets.ids) : contains(local.ids, subnet) ? subnet : ""])
    description = "pod subnet ids "
}

output "pod_subnet_cidr" {
    value = compact([for subnet in toset(data.aws_subnets.pod_subnets.ids) : contains(local.ids, subnet) ? local.subnets[local.subnet_keys[index(local.ids, subnet)]].cidr_block : ""])
}

output "pod_subnet_az" {
    value = compact([for subnet in toset(data.aws_subnets.pod_subnets.ids) : contains(local.ids, subnet) ? local.subnets[local.subnet_keys[index(local.ids, subnet)]].availability_zone : ""])
}

