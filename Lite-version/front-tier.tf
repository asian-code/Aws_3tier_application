#region s3 static page
resource "aws_s3_bucket" "static_website" {
  bucket = "hashstudio-static-site"

  tags = {
    Name = "hashstudio-static-site"
  }
}
# upload index file to s3
# resource "aws_s3_object" "index" {
#   bucket       = aws_s3_bucket.static_website.id
#   key          = "index.html"
#   source       = "index.html"
#   content_type = "text/html"
#   etag         = filemd5("index.html")
# }
# Data resource to list all files in the local directory --------------------------------
# data "local_file" "files" {
#   for_each = fileset("C:/Users/admin/Documents/HashStudio_nodejs_api/HashStudiosPatreonSupport_Private-main/HashStudiosPatreonSupport_Private-main/public", "**")
#   filename = each.value
# }


# resource "aws_s3_object" "files" {
#   for_each = data.local_file.files

#   bucket = aws_s3_bucket.static_website.id
#   key    = each.value
#   source = data.local_file.files[each.key].filename
# }
# S3 Web hosting
resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.static_website.id

  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "err_404.html"
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
        Sid       = "IPAllow"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource  = "${aws_s3_bucket.static_website.arn}/*"
      },
    ]
  })
  depends_on = [aws_s3_bucket.static_website]
}

# Output the website endpoint
output "website_endpoint" {
  value = aws_s3_bucket_website_configuration.website_config.website_endpoint
}
#endregion

#region CloudFront Distribution

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    # domain_name = aws_s3_bucket.static_website.website_endpoint (deprecated)
    domain_name = aws_s3_bucket.static_website.bucket_regional_domain_name
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

  # with domain------------------

  # aliases = [var.domain_name]

  # viewer_certificate {
  #   acm_certificate_arn      = aws_acm_certificate_validation.cert_validation.certificate_arn
  #   ssl_support_method       = "sni-only"
  #   minimum_protocol_version = "TLSv1.2_2021"
  # }

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
output "acm_certificate_domain_validation_options" {
  value       = aws_acm_certificate.ssl_certificate.domain_validation_options
  description = "Domain validation options for ACM certificate"
}
#region ACM certificate
resource "aws_acm_certificate" "ssl_certificate" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# resource "aws_acm_certificate_validation" "cert_validation" {
#   certificate_arn         = aws_acm_certificate.ssl_certificate.arn
#   validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
# }
#endregion