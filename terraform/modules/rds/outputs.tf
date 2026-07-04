output "db_endpoint" {
  description = "The connection endpoint for the RDS database"
  value       = aws_db_instance.mysql.endpoint
}

output "db_secret_arn" {
  description = "The ARN of the AWS Secrets Manager secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}