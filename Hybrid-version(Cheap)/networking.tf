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

resource "aws_subnet" "db" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnet_cidr
  availability_zone = "${var.main_az}a"
  tags = {
    Name = "db_subnet"
  }
}
resource "aws_subnet" "db2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.main_az}b"
  tags = {
    Name = "db_subnet-standby"
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main_igw"
  }
}
#region route tables
#public 
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
#db route table
resource "aws_route_table" "db-routet" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "secure_rt"
  }
}

resource "aws_route_table_association" "secure_db" {
  subnet_id      = aws_subnet.db.id
  route_table_id = aws_route_table.db-routet.id
}
#endregion
