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

  #region with domain------------------

  aliases = [ "benefits.${var.domain_name}" ]

  viewer_certificate {
    acm_certificate_arn      = "arn:aws:acm:us-east-1:767397882339:certificate/1570a4ef-fdd3-4ab6-97a7-92f5bbae6fd7"
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
  #endregion
  # Cache behavior for /user.html (requires signed cookies/URL)
  ordered_cache_behavior {
    path_pattern     = "/user.html"
    allowed_methods  = ["GET", "HEAD", "OPTIONS","PUT","POST","PATCH","DELETE"]
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
 ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS","PUT","POST","PATCH","DELETE"]
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
  # for all other behavior paths
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
 # for default cloudfront domain
  # viewer_certificate {
  #   cloudfront_default_certificate = true
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

# Output the CloudFront URL
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.cdn.domain_name
}


# output "acm_certificate_domain_validation_options" {
#   value       = aws_acm_certificate.ssl_certificate.domain_validation_options
#   description = "Domain validation options for ACM certificate"
# }
#region ACM certificate
# resource "aws_acm_certificate" "SSLcert" {
#   domain_name       = "*.${var.domain_name}"
#   validation_method = "DNS"

#   lifecycle {
#     create_before_destroy = true
#   }
# }
# import {
#   to = aws_acm_certificate.SSLcert
#   id = "arn:aws:acm:us-east-1:767397882339:certificate/1570a4ef-fdd3-4ab6-97a7-92f5bbae6fd7"
# }
# resource "aws_acm_certificate_validation" "cert_validation" {
#   certificate_arn         = aws_acm_certificate.ssl_certificate.arn
#   validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
# }
#endregion