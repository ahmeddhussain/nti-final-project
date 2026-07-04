variable "environment" {
  type        = string
  description = "The deployment environment name"
}

variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs where worker nodes will live"
}

variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for the EKS worker nodes (e.g., t3.small)"
}

variable "desired_nodes" {
  type        = number
  description = "Desired number of worker nodes"
}

variable "min_nodes" {
  type        = number
  description = "Minimum number of worker nodes for auto-scaling"
}

variable "max_nodes" {
  type        = number
  description = "Maximum number of worker nodes for auto-scaling"
}
variable "jenkins_security_group_id" {
  type        = string
  description = "The ID of the Jenkins Security Group to allow EKS access"
}