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
#region RDS Database
/*
* Important db features to have:
* Backups 
* delete protection
* updates
* data at rest- encryption
* db monitoring - metrics: cpu, memeory, storage
*/
resource "aws_db_instance" "default" {
  allocated_storage       = 20
  db_name                 = "mydb"
  engine                  = "mysql"
  engine_version          = "8.0.34"
  instance_class          = "db.t3.micro"
  username                = var.db_username
  password                = var.db_password
  parameter_group_name    = "default.mysql8.0"
  skip_final_snapshot     = true # snapshot store changes made, depends on original db.
  availability_zone       = "${var.main_az}a"
  identifier              = "hash-db"
  db_subnet_group_name    = aws_db_subnet_group.default.name
  backup_window           = "01:00-02:00" #stores backups in abstracted s3 bucks. can access in aws console
  backup_retention_period = 7
  deletion_protection  = var.env == "test" ? false:true
  auto_minor_version_upgrade = true                  # Enable automatic minor version upgrades
  maintenance_window         = "Sun:04:00-Sun:06:00" # Set maintenance window
  vpc_security_group_ids     = [aws_security_group.db_sg.id]
  multi_az                    = var.env =="test"? false : true # single az for testing only

  tags = {
    Name = "mydb"
  }
}
/* 
A DB subnet group allows you to specify a set of subnets in different Availability Zones (AZs). 
This ensures that your RDS instance can be deployed across multiple AZs, 
enhancing availability and fault tolerance1.
*/
resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.db.id,aws_subnet.db2.id]

  tags = {
    Name = "My DB subnet group"
  }
}
#endregion
#region SNS
# resource "aws_sns_topic" "rds_events" {
#   name = "rds-events-topic"
# }
variable "email_addresses" {
  description = "List of email addresses to subscribe to the SNS topic"
  type        = list(string)
  default     = ["ericnguyencode@gmail.com", "hashstudiosllc@gmail.com"]
}
# resource "aws_sns_topic_subscription" "rds_events_email" {
#   for_each  = toset(var.email_addresses)
#   topic_arn = aws_sns_topic.rds_events.arn
#   protocol  = "email"
#   endpoint  = each.value
# }

# resource "aws_db_event_subscription" "default" {
#   name        = "mydb-events"
#   sns_topic   = aws_sns_topic.rds_events.arn
#   source_type = "db-instance"

#   event_categories = [
#     "availability",
#     "deletion",
#     "failover",
#     "failure",
#     "low storage",
#     "maintenance",
#     "notification",
#     "read replica",
#     "recovery",
#     "restoration",
#   ]

#   source_ids = [aws_db_instance.default.id]
#   depends_on = [aws_db_instance.default]
#   enabled = true
# }
#endregion

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
    Name = "docker-vm"
  }

}
#endregion
#region s3 and frontend
resource "aws_s3_bucket" "static_website" {
  bucket = "hashstudio-static-site"

  tags = {
    Name        = "hashstudio-static-site"
  }
}
# upload index file to s3
resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.static_website.id
  key = "index.html"
  source = "index.html"
  content_type = "text/html"
  etag = filemd5("index.html")
}
# uplaod error file to s3
resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.static_website.id
  key = "error.html"
  source = "error.html"
  content_type = "text/html"
  etag = filemd5("index.html")
}
# S3 Web hosting
resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.static_website.id

  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}
resource "aws_s3_bucket_public_access_block" "access" {
  bucket = aws_s3_bucket.static_website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.static_website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "Public_access"
    Statement = [
      {
        Sid = "IPAllow"
        Effect = "Allow"
        Principal = "*"
        Action = ["s3:GetObject"]
        Resource  = "${aws_s3_bucket.static_website.arn}/*"
      },
    ]
  })
  depends_on = [ aws_s3_bucket.static_website ]
}

# Output the website endpoint
output "website_endpoint" {
  value = aws_s3_bucket_website_configuration.website_config.website_endpoint
}


#endregion

# CloudFront Distribution
/*

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.static_website.website_endpoint
    origin_id   = "S3-${var.domain_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = [var.domain_name]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.domain_name}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  viewer_certificate {
    acm_certificate_arn            = var.certificate_arn
    ssl_support_method              = "sni-only"
    minimum_protocol_version        = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "CloudFrontDistribution"
  }
}
resource "aws_route53_record" "www" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

# Output the CloudFront URL
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.cdn.domain_name
}
*/