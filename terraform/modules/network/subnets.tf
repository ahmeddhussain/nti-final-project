# Dynamically fetch available Availability Zones in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Create Public Subnets (For Jenkins and ELB)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                      = "${var.environment}-public-subnet-${count.index + 1}"
    Environment                               = var.environment
    "kubernetes.io/role/elb"                  = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Create Private Subnets (For EKS Nodes and RDS Database)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                      = "${var.environment}-private-subnet-${count.index + 1}"
    Environment                               = var.environment
    "kubernetes.io/role/internal-elb"         = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}