# Create the EKS Control Plane
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster_role.arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true # Allows you to run kubectl commands from your laptop
  }

  # Ensure the IAM Role is fully created before building the cluster
  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy
  ]

  tags = {
    Environment = var.environment
  }
}