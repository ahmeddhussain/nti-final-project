# Create AWS Backup Vault
resource "aws_backup_vault" "jenkins_vault" {
  name        = "${var.environment}-jenkins-backup-vault"
  tags = {
    Environment = var.environment
  }
}

# Create AWS Backup Plan (Daily Schedule)
resource "aws_backup_plan" "jenkins_plan" {
  name = "${var.environment}-jenkins-backup-plan"

  rule {
    rule_name         = "daily-backup-rule"
    target_vault_name = aws_backup_vault.jenkins_vault.name
    schedule          = "cron(0 12 * * ? *)" # Runs daily at 12:00 PM UTC

    lifecycle {
      delete_after = 7 # Retains daily backups for 7 days
    }
  }
}

# Assign the Jenkins EC2 Instance to the Backup Plan
resource "aws_backup_selection" "jenkins_selection" {
  iam_role_arn = aws_iam_role.backup_role.arn # Default AWS Managed Role
  name         = "${var.environment}-jenkins-backup-selection"
  plan_id      = aws_backup_plan.jenkins_plan.id

  # Selects your EC2 instance by its resource ARN
  resources = [
    aws_instance.jenkins.arn
  ]
}