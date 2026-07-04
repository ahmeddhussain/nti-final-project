# 1. Fetch the official AWS ELB Service Account ID for your specific region
data "aws_elb_service_account" "main" {}

# 2. Create the S3 Bucket for ELB Logs
resource "aws_s3_bucket" "elb_logs" {
  bucket        = "${var.environment}-nti-elb-access-logs-${random_id.bucket_suffix.hex}"
  force_destroy = true # Allows Terraform to delete the bucket even if it contains logs

  tags = {
    Environment = var.environment
    Purpose     = "ELB Access Logs"
  }
}

# 3. Add a random suffix to ensure the bucket name is globally unique
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# 4. Attach the Bucket Policy to allow ELB to write logs
resource "aws_s3_bucket_policy" "elb_logs_policy" {
  bucket = aws_s3_bucket.elb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.elb_logs.arn}/*"
      }
    ]
  })
}