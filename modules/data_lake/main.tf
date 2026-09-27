resource "aws_s3_bucket" "lake_bucket" {
  for_each = toset(var.lake_layers)

  bucket        = "lead-de-${var.environment}-${each.value}-data"
  force_destroy = var.environment == "dev" ? true : false # Protect prod data at all costs!

  tags = {
    Environment = var.environment
    Layer       = each.value
    ManagedBy   = "Terraform"
  }
}

# Explicitly enable daily request/object metrics for CloudWatch alarms to hook into
resource "aws_s3_bucket_metric" "bucket_metrics" {
  for_each = toset(var.lake_layers)
  bucket   = aws_s3_bucket.lake_bucket[each.value].id
  name     = "EntireBucket"
}
