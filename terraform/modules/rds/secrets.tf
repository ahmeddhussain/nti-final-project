# 1. Generate a random secure password
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "_!%^"
}

# 2. Create the Secret in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.environment}-rds-credentials"
  recovery_window_in_days = 0 # Forces immediate deletion upon terraform destroy (saves money)

  tags = {
    Environment = var.environment
  }
}

# 3. Store the Username and Password inside the Secret as JSON
resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = "mysql"
    host     = aws_db_instance.mysql.address
    dbname   = var.db_name
  })
}