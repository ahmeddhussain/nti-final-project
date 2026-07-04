module "network" {
  source               = "./modules/network"
  environment          = var.environment
  cluster_name         = var.cluster_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "compute" {
  source            = "./modules/compute"
  environment       = var.environment
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  ami_id            = var.ami_id
  instance_type     = var.instance_type
  public_key_path   = var.public_key_path
}
module "rds" {
  source             = "./modules/rds"
  environment        = var.environment
  vpc_id             = module.network.vpc_id
  vpc_cidr           = var.vpc_cidr
  private_subnet_ids = module.network.private_subnet_ids
  db_name            = var.db_name
  db_username        = var.db_username
  db_instance_class  = var.db_instance_class
}
module "storage" {
  source               = "./modules/storage"
  environment          = var.environment
  ecr_repository_names = var.ecr_repository_names
}
module "eks" {
  source                    = "./modules/eks"
  environment               = var.environment
  cluster_name              = var.cluster_name
  private_subnet_ids        = module.network.private_subnet_ids
  node_instance_type        = var.node_instance_type
  desired_nodes             = var.desired_nodes
  min_nodes                 = var.min_nodes
  max_nodes                 = var.max_nodes
  jenkins_security_group_id = module.compute.jenkins_sg_id 
}