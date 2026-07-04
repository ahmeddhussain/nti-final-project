# Upload your public SSH key to AWS
resource "aws_key_pair" "jenkins_key" {
  key_name   = "${var.environment}-jenkins-key"
  public_key = file(var.public_key_path)
}

# Create the Jenkins EC2 Instance in Public Subnet 1
resource "aws_instance" "jenkins" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_ids[0] # Places it in Public Subnet 1
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  # Ensures the instance has a public IP address
  associate_public_ip_address = true
  key_name               = aws_key_pair.jenkins_key.key_name 

  tags = {
    Name        = "${var.environment}-jenkins-server"
    Environment = var.environment
  }
}