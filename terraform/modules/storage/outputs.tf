output "s3_bucket_name" {
  description = "The name of the S3 bucket for ELB logs"
  value       = aws_s3_bucket.elb_logs.id
}

output "ecr_repository_urls" {
  description = "The URLs of the created ECR repositories"
  value       = aws_ecr_repository.app_repos[*].repository_url
}