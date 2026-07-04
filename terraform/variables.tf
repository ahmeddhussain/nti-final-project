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