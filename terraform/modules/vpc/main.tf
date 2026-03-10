data "aws_availability_zones" "available" {
  state = "available"
}

check "subnet_cidr_lengths" {
  assert {
    condition = (
      length(var.public_subnet_cidrs) == var.az_count &&
      length(var.private_subnet_cidrs) == var.az_count
    )
    error_message = "public_subnet_cidrs and private_subnet_cidrs lengths must match az_count."
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  public_subnets = {
    for idx, az in local.azs : az => {
      cidr = var.public_subnet_cidrs[idx]
      az   = az
    }
  }

  private_subnets = {
    for idx, az in local.azs : az => {
      cidr = var.private_subnet_cidrs[idx]
      az   = az
    }
  }

  base_tags = merge(var.tags, {
    Name = var.name
  })

  kubernetes_cluster_tag = var.kubernetes_cluster_name != "" ? {
    "kubernetes.io/cluster/${var.kubernetes_cluster_name}" = "shared"
  } : {}
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.base_tags, {
    Name = var.name
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.base_tags, {
    Name = "${var.name}-igw"
  })
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.az
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = true

  tags = merge(local.base_tags, {
    Name                     = "${var.name}-${each.key}-public"
    Tier                     = "public"
    "kubernetes.io/role/elb" = "1"
  }, local.kubernetes_cluster_tag)
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.az
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = false

  tags = merge(local.base_tags, {
    Name                              = "${var.name}-${each.key}-private"
    Tier                              = "private"
    "kubernetes.io/role/internal-elb" = "1"
  }, local.kubernetes_cluster_tag)
}

resource "aws_eip" "nat" {
  for_each = local.public_subnets

  domain = "vpc"

  tags = merge(local.base_tags, {
    Name = "${var.name}-${each.key}-nat-eip"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = local.public_subnets

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(local.base_tags, {
    Name = "${var.name}-${each.key}-nat"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.base_tags, {
    Name = "${var.name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = local.private_subnets

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[each.key].id
  }

  tags = merge(local.base_tags, {
    Name = "${var.name}-${each.key}-private-rt"
  })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}
