# databricks_foundation.tf

# 1. Dedicated S3 Bucket for the Databricks Root Metastore (DBFS / Unity Catalog Storage)
resource "aws_s3_bucket" "databricks_metastore" {
  bucket        = "lead-de-${var.environment}-databricks-metastore"
  force_destroy = var.environment == "prod" ? false : true
  tags          = { Environment = var.environment, ManagedBy = "Terraform" }
}

# 2. Strict Public Access Block for the Metastore Bucket
resource "aws_s3_bucket_public_access_block" "databricks_metastore_block" {
  bucket                  = aws_s3_bucket.databricks_metastore.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3. IAM Role allowing Databricks to read and write to your Medallion layers securely
resource "aws_iam_role" "databricks_storage_credential" {
  name = "${var.environment}-databricks-storage-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::414351767826:root" # Official global Databricks control plane AWS account ID
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "lead-de-${var.environment}-external-id"
          }
        }
      }
    ]
  })
}

# 4. IAM Access Policy linking the role directly to your dynamic lake layers
resource "aws_iam_policy" "databricks_lake_access" {
  name        = "${var.environment}-databricks-lake-access-policy"
  description = "Provides Databricks compute runtime access to the Bronze, Silver, and Gold layers"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::lead-de-${var.environment}-*",
          "arn:aws:s3:::lead-de-${var.environment}-*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "databricks_attach" {
  role       = aws_iam_role.databricks_storage_credential.name
  policy_arn = aws_iam_policy.databricks_lake_access.arn
}
