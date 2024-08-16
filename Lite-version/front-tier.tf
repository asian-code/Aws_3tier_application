#region s3 static page
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
resource "aws_s3_object" "error" {
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

#region CloudFront Distribution

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.static_website.website_endpoint
    origin_id   = aws_s3_bucket.static_website.id

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

#   aliases = [var.domain_name]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.static_website.id

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
    cloudfront_default_certificate = true
    # Remove the following lines if you're not using a custom SSL certificate
    # acm_certificate_arn      = var.certificate_arn
    # ssl_support_method       = "sni-only"
    # minimum_protocol_version = "TLSv1.2_2021"
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
#endregion
/*
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
/*
*/
# Output the CloudFront URL
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.cdn.domain_name
}
