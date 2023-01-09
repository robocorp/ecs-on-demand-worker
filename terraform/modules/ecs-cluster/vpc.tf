data "aws_availability_zones" "azs" {
  state = "available"
}

locals {
  subnet_count = min(var.az_count, length(data.aws_availability_zones.azs.names))
}

resource "aws_vpc" "vpc" {
  cidr_block = "172.17.0.0/16"
  assign_generated_ipv6_cidr_block = false
  enable_dns_hostnames = false

  tags = {
    Name = var.id
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.id}-igw"
  }
}

resource "aws_subnet" "private_subnets" {
  count                           = local.subnet_count
  vpc_id                          = aws_vpc.vpc.id
  cidr_block                      = cidrsubnet("172.17.0.0/20", 4, count.index)
  assign_ipv6_address_on_creation = false
  availability_zone               = data.aws_availability_zones.azs.names[count.index]

  tags = {
    Name   = "${var.id}-private-${data.aws_availability_zones.azs.names[count.index]}"
  }
}

resource "aws_subnet" "public_subnets" {
  count                           = local.subnet_count
  vpc_id                          = aws_vpc.vpc.id
  cidr_block                      = cidrsubnet("172.17.16.0/20", 4, count.index)
  assign_ipv6_address_on_creation = false
  availability_zone               = data.aws_availability_zones.azs.names[count.index]

  tags = {
    Name = "${var.id}-public-${data.aws_availability_zones.azs.names[count.index]}"
  }
}

resource "aws_eip" "nat" {
  vpc   = true
  count = length(aws_subnet.public_subnets)

  tags = {
    Name = "${var.id}-nat-${data.aws_availability_zones.azs.names[count.index]}"
  }
}

resource "aws_route_table" "public" {
  count  = length(aws_subnet.public_subnets)
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.id}-public-${data.aws_availability_zones.azs.names[count.index]}"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public_subnets)
  subnet_id      = element(aws_subnet.public_subnets.*.id, count.index)
  route_table_id = element(aws_route_table.public.*.id, count.index)
}

resource "aws_route" "public_internet_gateway" {
  count                  = length(aws_subnet.public_subnets)
  route_table_id         = element(aws_route_table.public.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table" "private" {
  count  = length(aws_subnet.private_subnets)
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.id}-private-${data.aws_availability_zones.azs.names[count.index]}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private_subnets)
  subnet_id      = element(aws_subnet.private_subnets.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

resource "aws_nat_gateway" "natgw" {
  count         = length(aws_subnet.public_subnets)
  allocation_id = element(aws_eip.nat.*.id, count.index)
  subnet_id     = element(aws_subnet.public_subnets.*.id, count.index)

  tags = {
    Name = "${var.id}-ecs-instances-${data.aws_availability_zones.azs.names[count.index]}"
  }
}

resource "aws_route" "private_nat_gateway" {
  count                  = length(aws_subnet.private_subnets)
  route_table_id         = element(aws_route_table.private.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.natgw.*.id, count.index)
}
