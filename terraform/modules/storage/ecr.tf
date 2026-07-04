# Create ECR Repositories dynamically based on the list variable
resource "aws_ecr_repository" "app_repos" {
  count                = length(var.ecr_repository_names)
  name                 = "${var.environment}-${var.ecr_repository_names[count.index]}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # Allows Terraform to destroy it even if it contains Docker images

  image_scanning_configuration {
    scan_on_push = true # Automatically scans for basic vulnerabilities on push
  }

  tags = {
    Environment = var.environment
  }
}