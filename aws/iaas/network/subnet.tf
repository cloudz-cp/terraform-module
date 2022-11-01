locals {
    public_tag_key      = "kubernetes.io/role/elb"
    internal_tag_key    = "kubernetes.io/role/internal-elb"
    subnet_key          = keys(var.subnets)
    public_subnets      = compact([for key, subnet in var.subnets : subnet.is_public == true ? key : ""])   
    eks_subnets         = compact([for key, subnet in var.subnets : subnet.subnet_type == "eks" ? key : ""])
    nat_subnets         = compact([for key, subnet in var.subnets : subnet.subnet_type == "nat" ? key : ""])
    pod_subnets         = compact([for key, subnet in var.subnets : subnet.subnet_type == "pod" ? key : ""])    
    subnets             = aws_subnet.eks
}

resource "aws_subnet" "eks" {
    depends_on = [
        module.vpc
    ]
    for_each = var.subnets
    vpc_id = module.vpc.vpc_id

    cidr_block = each.value["subnet_cidr"]   
    availability_zone = each.value["az"]   

    tags = {
        Name = each.key
        "kubernetes.io/cluster/${var.eks.name}" = "shared"
        (each.value["is_public"] == true ? local.public_tag_key : local.internal_tag_key) = 1
    }
}

resource "aws_route_table" "public" {
    vpc_id = module.vpc.vpc_id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.eks.id
    }
    tags = {
        Name = format("%s-public-rt", var.eks.name)
    }
}

resource "aws_route_table" "nat" {
    count = length(aws_nat_gateway.eks)
    vpc_id = module.vpc.vpc_id

    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.eks[count.index].id
    }

    tags = {
        Name = format("%s-nat-rt", var.eks.name)
    }

}

// public subnet들과 resource.aws_route_table.public table연결 
resource "aws_route_table_association" "public_igw" {
    count = length(local.public_subnets)
    subnet_id  = aws_subnet.eks[local.public_subnets[count.index]].id
    route_table_id = aws_route_table.public.id
}

// eks subnet들과 resource.aws_route_table.nat table연결 
resource "aws_route_table_association" "eks_nat" {
    count = length(local.eks_subnets) > 0 && length(aws_route_table.nat) > 0 ? length(local.eks_subnets) : 0
    subnet_id  = aws_subnet.eks[local.eks_subnets[count.index]].id
    route_table_id = aws_route_table.nat[count.index].id
}


resource "aws_internet_gateway" "eks" {
  vpc_id            = module.vpc.vpc_id

  tags = {
    Name = format("%s-cluster-igw", var.eks.name)
  }
}

resource "aws_eip" "eks" {
    count = length(setintersection(local.public_subnets, local.nat_subnets))>0 ? length(var.azs) :0
    vpc = true

    tags = {
        Name = format("%s-cluster-eip",var.eks.name)
    }
}

resource "aws_nat_gateway" "eks" {
    count = length(local.nat_subnets)
    allocation_id = aws_eip.eks[count.index].id
    subnet_id     = aws_subnet.eks[local.nat_subnets[count.index]].id

    tags = {
        Name =  local.nat_subnets[count.index]
    }
    depends_on = [aws_internet_gateway.eks]
}