resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "main_vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.main_az}a"

  tags = {
    Name = "public_subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "${var.main_az}a"
  tags = {
    Name = "private_subnet"
  }
}

resource "aws_subnet" "db" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnet_cidr
  availability_zone = "${var.main_az}a"
  tags = {
    Name = "db_subnet"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main_igw"
  }
}
# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public_rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
# private and db route table
resource "aws_route_table" "app-routet" {
  vpc_id = aws_vpc.main.id
route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.public.id
  }
  tags = {
    Name = "app_rt"
  }
}
resource "aws_route_table" "db-routet" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "secure_rt"
  }
}

resource "aws_route_table_association" "secure_app" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.app-routet.id
}
resource "aws_route_table_association" "secure_db" {
  subnet_id      = aws_subnet.db.id
  route_table_id = aws_route_table.db-routet.id
}
# Other Components 
resource "aws_eip" "natIP" {
  domain = "vpc"
  tags = {
    Name = "NAT-eip-tf"
  }
}
resource "aws_nat_gateway" "public" {
  allocation_id = aws_eip.natIP.id
  subnet_id     = aws_subnet.public.id
  depends_on = [aws_internet_gateway.gw]
  tags = {
    Name = "public-NAT-tf"
  }
}
