output "bucket_name" {
  description = "Name of the environment's Glue artifact bucket."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "ARN of the environment's Glue artifact bucket."
  value       = aws_s3_bucket.this.arn
}