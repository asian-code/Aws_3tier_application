#region s3 static page
resource "aws_s3_bucket" "static_website" {
  bucket = "hashstudio-static-site"
}
# upload index file to s3 --------------------
# resource "aws_s3_object" "index" {
#   bucket       = aws_s3_bucket.static_website.id
#   key          = "index.html"
#   source       = "index.html"
#   content_type = "text/html"
#   etag         = filemd5("index.html")
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
# resource "aws_s3_bucket_public_access_block" "access" {
#   bucket = aws_s3_bucket.static_website.id

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for ${aws_s3_bucket.static_website.id}"
}
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.static_website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.oai.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.static_website.arn}/*"
      }
    ]
  })
}
#endregion
# Output the website endpoint
output "s3_website_endpoint" {
  value = aws_s3_bucket_website_configuration.website_config.website_endpoint
}
#endregion

#region CloudFront Distribution

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    # domain_name = aws_s3_bucket.static_website.website_endpoint (deprecated)
    domain_name = aws_s3_bucket.static_website.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.static_website.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  # Cache behavior for /user.html (requires signed cookies)
  ordered_cache_behavior {
    path_pattern     = "/user.html"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.static_website.id}"
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"  # CachingOptimized policy ID

    # CANT HAVE THIS IF USING MANAGED CACHE POLICY
    # forwarded_values {
    #   query_string = false
    #   cookies {
    #     forward = "none"
    #   }
    # }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true  # Enable automatic object compression

    # Enable signed cookies for /user.html
    trusted_key_groups=["5c4e2eba-d6c2-4a0a-aae4-86337b6b7d87"]
  }

  # for all other paths
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.static_website.id}"
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"  # CachingOptimized policy ID

    # CANT HAVE THIS IF USING MANAGED CACHE POLICY
    # forwarded_values {
    #   query_string = false
    #   cookies {
    #     forward = "none"
    #   }
    # }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true  # Enable automatic object compression

  }

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
    Name = "s3-static-website-cdn"
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
# output "acm_certificate_domain_validation_options" {
#   value       = aws_acm_certificate.ssl_certificate.domain_validation_options
#   description = "Domain validation options for ACM certificate"
# }
#region ACM certificate
# resource "aws_acm_certificate" "ssl_certificate" {
#   domain_name       = var.domain_name
#   validation_method = "DNS"

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_acm_certificate_validation" "cert_validation" {
#   certificate_arn         = aws_acm_certificate.ssl_certificate.arn
#   validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
# }
#endregion