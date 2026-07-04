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