variable "environment" {
  type        = string
  description = "The deployment environment name"
}

variable "ecr_repository_names" {
  type        = list(string)
  description = "List of ECR repository names to create"
}