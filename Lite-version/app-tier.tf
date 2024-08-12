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
    Name = "docker-vm"
  }

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