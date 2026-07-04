variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
}

variable "environment" {
  type        = string
  description = "The deployment environment name"
}

variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster for subnet tagging"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the public subnets"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the private subnets"
}