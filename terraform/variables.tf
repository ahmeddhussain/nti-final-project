variable "aws_region" {
  type        = string
  description = "The AWS region where all resources will be deployed"
}

variable "environment" {
  type        = string
  description = "The deployment environment name (e.g., dev, prod)"
}

variable "cluster_name" {
  type        = string
  description = "The name of the AWS EKS Cluster"
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the custom VPC"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the public subnets"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the private subnets"
}
# ... keeping your existing variables ...

variable "ami_id" {
  type        = string
  description = "The AMI ID for the Jenkins EC2 instance (e.g., Ubuntu/RHEL)"
}

variable "instance_type" {
  type        = string
  description = "The instance type for the Jenkins EC2 instance (e.g., t3.medium)"
}
variable "public_key_path" {
  type        = string
  description = "The local path to the SSH public key"
}
variable "db_name" {
  type        = string
  description = "The initial database name"
}
variable "db_username" {
  type        = string
  description = "The master username for the database"
}
variable "db_instance_class" {
  type        = string
  description = "The instance type for the RDS database"
}
variable "ecr_repository_names" {
  type        = list(string)
  description = "Names of the ECR repositories to create"
}
variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for the EKS worker nodes"
}
variable "desired_nodes" {
  type        = number
  description = "Desired number of worker nodes"
}
variable "min_nodes" {
  type        = number
  description = "Minimum number of worker nodes"
}
variable "max_nodes" {
  type        = number
  description = "Maximum number of worker nodes"
}