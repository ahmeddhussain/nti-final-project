# Create the RDS Subnet Group (Required to put DB in Private Subnets)
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.environment}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Environment = var.environment
  }
}

# Create the MySQL RDS Instance
resource "aws_db_instance" "mysql" {
  identifier           = "${var.environment}-mysql-db"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = var.db_instance_class
  allocated_storage    = 20 # 20 GB is the max Free Tier limit
  
  db_name              = var.db_name
  username             = var.db_username
  password             = random_password.db_password.result
  
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  publicly_accessible    = false # Ensures it stays completely private
  skip_final_snapshot    = true  # Required to easily destroy the DB without getting charged for a snapshot

  tags = {
    Environment = var.environment
  }
}