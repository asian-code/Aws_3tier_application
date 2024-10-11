# for main componets of all tiers

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

#region EC2
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

# Create a listener on port 443 for the ALB
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"  # Use a recommended SSL policy
  certificate_arn   = aws_acm_certificate.backend_cert.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}
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
# resource "aws_route53_record" "cert_validation" {
#   for_each = {
#     for dvo in aws_acm_certificate.backend_cert.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   }

#   zone_id = aws_route53_zone.main.zone_id 
#   name    = each.value.name
#   type    = each.value.type
#   ttl     = 60
#   records = [each.value.record]
#   depends_on =[aws_acm_certificate.backend_cert]

# }
# resource "aws_acm_certificate_validation" "app_cert_validation" {
#   certificate_arn         = aws_acm_certificate.backend_cert.arn
#   validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
#   depends_on = [aws_route53_record.cert_validation]
  
# }

  output "instance_public_ip" {
  description = "The public IP address of the API-VM EC2 instance"
  value       = aws_instance.main.public_ip
}


#endregion
