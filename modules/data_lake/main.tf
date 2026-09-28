resource "aws_s3_bucket" "lake_bucket" {
  for_each = toset(var.lake_layers)

  bucket        = "lead-de-${var.environment}-${each.value}-data"
  force_destroy = var.environment == "dev"

  tags = {
    Environment = var.environment
    Layer       = each.value
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "block_public" {
  for_each = toset(var.lake_layers)
  bucket   = aws_s3_bucket.lake_bucket[each.value].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# Request metrics are retained for future request-rate/error alarms.
resource "aws_s3_bucket_metric" "bucket_metrics" {
  for_each = toset(var.lake_layers)
  bucket   = aws_s3_bucket.lake_bucket[each.value].id
  name     = "EntireBucket"
}

resource "aws_s3_bucket_versioning" "lake_versioning" {
  for_each = toset(var.lake_layers)
  bucket   = aws_s3_bucket.lake_bucket[each.value].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lake_encryption" {
  for_each = toset(var.lake_layers)
  bucket   = aws_s3_bucket.lake_bucket[each.value].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lake_lifecycle" {
  for_each = toset(var.lake_layers)
  bucket   = aws_s3_bucket.lake_bucket[each.value].id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
