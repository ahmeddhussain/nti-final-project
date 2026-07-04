variable "environment" {
  type        = string
  description = "The deployment environment name"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC"
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block of the VPC to allow database connections"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for the RDS Subnet Group"
}

variable "db_name" {
  type        = string
  description = "The name of the initial database to create"
}

variable "db_username" {
  type        = string
  description = "The master username for the database"
}

variable "db_instance_class" {
  type        = string
  description = "The instance type for the RDS database (e.g., db.t3.micro for free tier)"
}