locals {
    eks_subnet_names = compact([for key, subnet in var.subnets : subnet.subnet_type == "eks" ? key : ""])
    eks_subnet_cidrs = compact([for key, subnet in var.subnets : subnet.subnet_type == "eks" ? subnet.subnet_cidr : ""])
}

data "aws_subnets" "eks_subnets" {
    filter {
        name   = "vpc-id"
        values = [var.vpc.vpc_id]
    }
    filter {
        name = "tag:Name"
        values = local.eks_subnet_names
    }
}


resource  "aws_efs_file_system" "filesystem" {
    for_each = var.efs
    encrypted = true
    tags      = {
        Name        = "${each.key}"
        Terraform   = "true"
        CreatedBy   = "zcp-mcm-provisioner"
    }
}

resource "aws_efs_access_point" "efs_access_point" {
    depends_on = [
      aws_efs_file_system.filesystem
    ]

    #for_each = var.efs
    #idx = index(keys(var.efs), each.key)
    #file_system_id = aws_efs_file_system.filesystem[index(keys(var.efs), each.key)].id
    for_each = aws_efs_file_system.filesystem
    file_system_id = aws_efs_file_system.filesystem[each.key].id 
    root_directory {
        creation_info {
            owner_gid = 0
            owner_uid = 0
            permissions = "755"
            #owner_gid   = each.value["efs_access_point"].owner_gid
            #owner_uid   = each.value["efs_access_point"].owner_uid
            #permissions = each.value["efs_access_point"].permissions
    }
    path = "/dynamic_provisioning"
    #path = each.value["efs_access_point"].root_path
  }

  tags = {
    Name        = "${each.key}"
    Terraform   = "true"
    CreatedBy   = "zcp-mcm-provisioner"
  }
}

resource "aws_efs_backup_policy" "backup_policy" {
    depends_on = [
      aws_efs_file_system.filesystem
    ]

    for_each = aws_efs_file_system.filesystem
    file_system_id = aws_efs_file_system.filesystem[each.key].id
    #for_each = var.efs
#    idx = index(keys(var.efs), each.key)

    #file_system_id = aws_efs_file_system.filesystem[index(keys(var.efs), each.key)].id
    backup_policy {
        #status = each.value["backup_policy"]
        status = "ENABLED"
    }
}

resource "aws_security_group" "security_group" {
    name        = "eks-efs-sg-${var.eks.cluster_id}"
    description = "NFS access to EFS from EKS worker nodes"
    vpc_id      = var.vpc.vpc_id

    ingress {
        description = "NFS"
        from_port   = 2049
        to_port     = 2049
        protocol    = "tcp"
        cidr_blocks = local.eks_subnet_cidrs
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name        = "eks-efs-sg-${var.eks.cluster_id}"
        Terraform   = "true"
        CreatedBy   = "zcp-mcm-provisioner"
    }
}


locals {
    fs_ids = [
        for k,v in aws_efs_file_system.filesystem :
        v.id
    ]
    subnet_fs = [
        for pair in setproduct(local.fs_ids, data.aws_subnets.eks_subnets.ids) : {
            fs_id  = pair[0]
            subnet_id = pair[1]
        }
    ]
}

resource "aws_efs_mount_target" "mount_target" {
    depends_on = [
      aws_efs_access_point.efs_access_point,
      local.subnet_fs
    ]
    
    count = 2#length(local.subnet_fs)
    subnet_id = local.subnet_fs[count.index].subnet_id
    file_system_id = local.subnet_fs[count.index].fs_id
    security_groups = [aws_security_group.security_group.id]

    #for_each = { for entry in local.subnet_fs: "${entry.fs_id}:${entry.subnet_id}" => entry}
    #subnet_id = each.value.subnet_id
    #file_system_id = each.value.fs_id
}
