data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}
resource "aws_instance" "main" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro" # Instance type
  # key_name                    = "my-key-pair" # Replace with your key pair name
  vpc_security_group_ids      = [aws_security_group.public_sg.id]
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  availability_zone           = "${var.main_az}a"
  tags = {
    Name = "api-vm"
  }
 
}


#region ALB, target group, group attachment, security groups
# resource "aws_security_group" "test_sg" {
#   name        = "ALB-sg-tf"
#   description = "inbound only to p:80,443. outbound to all, outbound to db-sg"
#   vpc_id      = aws_vpc.main.id
#   tags = {
#     Name = "public_sg"
#   }
# }
# resource "aws_vpc_security_group_ingress_rule" "alb_out" {
#   security_group_id = aws_security_group.test_sg.id
#   cidr_ipv4         = "0.0.0.0/0"
#   from_port         = 443
#   ip_protocol       = "tcp"
#   to_port           = 443
# }

# resource "aws_vpc_security_group_egress_rule" "alb_in" {
#   security_group_id = aws_security_group.test_sg.id
#   cidr_ipv4         = "0.0.0.0/0"
#   ip_protocol       = "-1" # semantically equivalent to all ports
# }
# # Create a APP load balancer
# resource "aws_lb" "test_lb" {
#   name               = "app-load-balancer"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.test_sg.id]
#   subnets            = [aws_subnet.public.id,aws_subnet.db2.id]  # Add your subnets here
# }

# # Target Group
# resource "aws_lb_target_group" "test_tg" {
#   name     = "api-target-group-test"
#   port     = 3000
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.main.id # Make sure this references your VPC

#   health_check {
#     path                = "/"
#     interval            = 30
#     timeout             = 5
#     healthy_threshold   = 5
#     unhealthy_threshold = 2
#     matcher             = "200-499"
#   }
# }
# # Target Group Attachment
# resource "aws_lb_target_group_attachment" "test_tg_attachment" {
#   target_group_arn = aws_lb_target_group.test_tg.arn
#   target_id        = aws_instance.main.id
#   port             = 3000
# }
# resource "aws_lb_listener" "test_app_listener" {
#   load_balancer_arn = aws_lb.test_lb.arn
#   port              = "443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"  # Use a recommended SSL policy
#   certificate_arn   = aws_acm_certificate.backend_cert.arn
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.test_tg.arn
#   }
#   depends_on = [ aws_acm_certificate.backend_cert ]
# }
#endregion
#region API gateway

# resource "aws_iam_role" "api_gateway_role" {
#   name               = "api-gateway-role"
#   assume_role_policy = jsonencode({
#     "Version" : "2012-10-17",
#     "Statement" : [{
#       "Effect" : "Allow",
#       "Principal" : {
#         "Service" : "apigateway.amazonaws.com"
#       },
#       "Action" : "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_role_policy" "api_gateway_policy" {
#   role = aws_iam_role.api_gateway_role.id
#   policy = jsonencode({
#     "Version" : "2012-10-17",
#     "Statement" : [{
#       "Effect" : "Allow",
#       "Action" : [
#         "ec2:DescribeInstances",
#         "execute-api:Invoke"
#       ],
#       "Resource" : "*"
#     }]
#   })
# }
resource "aws_apigatewayv2_api" "main" {
  name          = "api-gateway-ec2"
  protocol_type = "HTTP"
}
# Auto deloy stage
resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.main.id
  name   = "$default"
  auto_deploy = true
}
output "api-gateway-stage-invoke_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}
resource "aws_apigatewayv2_route" "allroute" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.main_integration.id}"

}
resource "aws_apigatewayv2_integration" "main_integration" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "HTTP_PROXY"
  integration_uri  = "http://${aws_instance.main.public_ip}:3000/{proxy}"
  integration_method = "ANY"
}


resource "aws_apigatewayv2_domain_name" "backend" {
  domain_name = "benefits-backend.hashstudiosllc.com"
   domain_name_configuration {
    certificate_arn = aws_acm_certificate.backend_cert.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}


#endregion

#region proxy port 80 to 3000
resource "aws_lb" "app_lb" {
  name               = "apivm-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public_sg.id]
  subnets            = [aws_subnet.public.id,aws_subnet.db2.id] 

  enable_deletion_protection = false
}

# Create a Target Group that forwards to port 3000
resource "aws_lb_target_group" "app_tg" {
  name     = "api-target-group"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/login"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200-499"
  }
}

# Add targets (EC2 instances) to the target group
resource "aws_lb_target_group_attachment" "tg_attachment" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.main.id  # Replace with your instance ID
  port             = 3000
}

# Create a listener on port 443 for the ALB (doesnt work)
# resource "aws_lb_listener" "app_listener" {
#   load_balancer_arn = aws_lb.app_lb.arn
#   port              = "443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"  # Use a recommended SSL policy
#   certificate_arn   = aws_acm_certificate.backend_cert.arn
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app_tg.arn
#   }
# depends_on = [ aws_acm_certificate.backend_cert ]
# }

#endregion

resource "aws_acm_certificate" "backend_cert" {
  domain_name       = "*.${var.domain_name}" # "benefits-backend.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
   tags = {
    Name = "backend-certificate"
  }
}
# resource "aws_acm_certificate_validation" "cert_validation" {
#   certificate_arn = aws_acm_certificate.backend_cert.arn
#   validation_record_fqdns = [
#     aws_route53_record.cert_validation.fqdn,
#   ]
# }

  output "instance_public_ip" {
  description = "The public IP address of the API-VM EC2 instance"
  value       = aws_instance.main.public_ip
}


