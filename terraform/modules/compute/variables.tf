variable "environment" {
  type        = string
  description = "The deployment environment name"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where security groups will be created"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnet IDs to place the EC2 instance"
}

variable "ami_id" {
  type        = string
  description = "The AMI ID for the Jenkins EC2 instance"
}

variable "instance_type" {
  type        = string
  description = "The instance type for the Jenkins EC2 instance"
}
variable "public_key_path" {
  type        = string
  description = "The local path to the SSH public key"
}