terraform {
  backend "s3" {
    bucket       = "ahmed-final-project-statefile"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}