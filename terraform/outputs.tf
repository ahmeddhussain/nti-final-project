output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "jenkins_public_ip" {
  description = "The public IP address of the Jenkins server"
  value       = module.compute.jenkins_public_ip
}