locals {
    merged_s3 = merge(var.s3, {
        format("%s-velero-s3-registry", var.eks.cluster_id) = {
            "${local.block_public_acls}"         = true
            "${local.block_public_policy}"       = true
            "${local.ignore_public_acls}"        = true
            "${local.restrict_public_buckets}"   = true
        }
    })
    block_public_acls = "block_public_acls"
    block_public_policy = "block_public_policy"
    ignore_public_acls = "ignore_public_acls"
    restrict_public_buckets = "restrict_public_buckets"
}

resource "aws_s3_bucket" "zcp" {
    for_each = local.merged_s3    
    bucket = lower("${each.key}")
}

resource "aws_s3_bucket_public_access_block" "zcp" {
    depends_on = [
      aws_s3_bucket.zcp
    ]
    for_each = local.merged_s3 
    bucket = aws_s3_bucket.zcp[each.key].id

    block_public_acls       = each.value[local.block_public_acls]
    block_public_policy     = each.value[local.block_public_policy]
    ignore_public_acls      = each.value[local.ignore_public_acls]
    restrict_public_buckets = each.value[local.restrict_public_buckets]
}