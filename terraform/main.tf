# ==============================================================================
# 1. AWS VPC (Virtual Private Cloud) & Network Subnets
# ==============================================================================

# Fetch availability zones available in the target AWS Region (e.g. us-east-1a, 1b, 1c)
data "aws_availability_zones" "available" {}

# Create the VPC
resource "aws_vpc" "weather_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name                                        = "weather-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Create Public Subnets (Hosts Internet Gateways and Load Balancers)
resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.weather_vpc.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "weather-public-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1" # Tells Kubernetes it can place public Load Balancers here
  }
}

# Create Private Subnets (Hosts EKS Worker Nodes)
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.weather_vpc.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                        = "weather-private-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1" # Tells Kubernetes it can place private Load Balancers here
  }
}

# ==============================================================================
# 2. Gateways & Routing Tables (How traffic moves)
# ==============================================================================

# Internet Gateway (The Front Door for Public Traffic)
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.weather_vpc.id
  tags   = { Name = "weather-igw" }
}

# Elastic IP for NAT Gateway (A static IP address in the cloud)
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.gw]
  tags       = { Name = "weather-nat-eip" }
}

# NAT Gateway (The One-Way Mirror router for Private Subnets)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Sits in the first public subnet
  depends_on    = [aws_internet_gateway.gw]
  tags          = { Name = "weather-nat" }
}

# Public Route Table (Sends public traffic directly to the Internet Gateway)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.weather_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "weather-public-rt" }
}

# Private Route Table (Sends private traffic to the NAT Gateway to go out)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.weather_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "weather-private-rt" }
}

# Associate Route Tables with Subnets
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ==============================================================================
# 3. IAM Security Roles (Permissions) for EKS Control Plane
# ==============================================================================

resource "aws_iam_role" "eks_cluster" {
  name = "weather-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# ==============================================================================
# 4. EKS Cluster (The Kubernetes Brains)
# ==============================================================================

resource "aws_eks_cluster" "weather" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# ==============================================================================
# 5. IAM Security Roles for Worker Nodes (EC2 Instances)
# ==============================================================================

resource "aws_iam_role" "eks_nodes" {
  name = "weather-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# ==============================================================================
# 6. EKS Node Group (The Worker Nodes that run our Containers)
# ==============================================================================

resource "aws_eks_node_group" "weather_nodes" {
  cluster_name    = aws_eks_cluster.weather.name
  node_group_name = "weather-node-group"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id # Workers live safely inside private subnets

  scaling_config {
    desired_size = 2 # Starts with 2 virtual servers
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.medium"] # Standard developer instance (2 vCPUs, 4GB RAM)

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_registry_policy,
  ]
}