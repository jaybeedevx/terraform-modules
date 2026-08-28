locals {
  # Carve /20 subnets out of the /16 VPC CIDR — adjust the newbits value
  # if your vpc_cidr isn't a /16, this assumes that default.
  public_subnet_cidrs  = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnet_cidrs = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 4, i + length(var.azs))]

  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-igw"
  })
}

# --------------------------
# PUBLIC SUBNETS
# --------------------------
resource "aws_subnet" "public" {
  count                   = length(var.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  # Required for the AWS Load Balancer Controller to auto-discover
  # public subnets for internet-facing ALBs.
  tags = merge(local.common_tags, {
    Name                                        = "${var.cluster_name}-public-${var.azs[count.index]}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --------------------------
# PRIVATE SUBNETS
# --------------------------
resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  # Required for internal ALBs (kubernetes.io/role/internal-elb) and
  # Karpenter's EC2NodeClass subnet discovery (karpenter.sh/discovery) —
  # this second tag is what the EC2NodeClass in eks-platform matches on.
  tags = merge(local.common_tags, {
    Name                                        = "${var.cluster_name}-private-${var.azs[count.index]}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "karpenter.sh/discovery"                    = var.cluster_name
  })
}

# --------------------------
# NAT — single shared vs. one per AZ (var.single_nat_gateway)
# --------------------------
resource "aws_eip" "nat" {
  count  = var.single_nat_gateway ? 1 : length(var.azs)
  domain = "vpc"
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-nat-eip-${count.index}"
  })
}

resource "aws_nat_gateway" "this" {
  count         = var.single_nat_gateway ? 1 : length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-nat-${count.index}"
  })
  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "private" {
  count  = length(var.azs)
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
  }
  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-private-rt-${count.index}"
  })
}

resource "aws_route_table_association" "private" {
  count          = length(var.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}