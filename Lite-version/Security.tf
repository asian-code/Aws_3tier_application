# for security

#region Public SG ---
resource "aws_security_group" "public_sg" {
  name        = "public-sg-tf"
  description = "inbound only to p:80,443. outbound to all, outbound to db-sg"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "public_sg"
  }
}
resource "aws_vpc_security_group_egress_rule" "public_allow_all_ipv4" {
  security_group_id = aws_security_group.public_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
resource "aws_vpc_security_group_egress_rule" "public_allow_all_dbsg" {
  security_group_id            = aws_security_group.public_sg.id
#   cidr_ipv4                    = "0.0.0.0/0"
  ip_protocol                  = "-1" # semantically equivalent to all ports
  referenced_security_group_id = aws_security_group.db_sg.id
}
# resource "aws_vpc_security_group_ingress_rule" "public_allow_http_ipv4" {
#   security_group_id = aws_security_group.public_sg.id
#   cidr_ipv4         = "0.0.0.0/0"
#   from_port         = 80
#   ip_protocol       = "tcp"
#   to_port           = 80
# }
resource "aws_vpc_security_group_ingress_rule" "public_allow_https_ipv4" {
  security_group_id = aws_security_group.public_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
resource "aws_vpc_security_group_ingress_rule" "public_allow_node_ipv4" {
  security_group_id = aws_security_group.public_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 3000
  ip_protocol       = "tcp"
  to_port           = 3000
}
# Ec2 connect service
resource "aws_vpc_security_group_ingress_rule" "allow-ec2-connect" {
  security_group_id = aws_security_group.public_sg.id
  cidr_ipv4         = "3.16.146.0/29"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}
#endregion 
#region db SG ---
resource "aws_security_group" "db_sg" {
  name        = "db-sg-tf"
  description = "inbound and outbound to public sg"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "db_sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "db_allow_from_app" {
  security_group_id            = aws_security_group.db_sg.id
#   cidr_ipv4                    = "0.0.0.0/0"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.public_sg.id

}
resource "aws_vpc_security_group_egress_rule" "db_allow_all_to_app" {
  security_group_id            = aws_security_group.db_sg.id
#   cidr_ipv4                    = "0.0.0.0/0"
  ip_protocol                  = "-1" # semantically equivalent to all ports
  referenced_security_group_id = aws_security_group.public_sg.id
}
#endregion