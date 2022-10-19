resource "aws_s3_bucket" "zcp" {
    for_each = var.s3    
    bucket = lower("${each.key}")
}

resource "aws_s3_bucket_public_access_block" "zcp" {
    depends_on = [
      aws_s3_bucket.zcp
    ]
    for_each = var.s3
    bucket = aws_s3_bucket.zcp[each.key].id

    block_public_acls       = each.value["block_public_acls"]
    block_public_policy     = each.value["block_public_policy"]
    ignore_public_acls      = each.value["ignore_public_acls"]
    restrict_public_buckets = each.value["restrict_public_buckets"]
}