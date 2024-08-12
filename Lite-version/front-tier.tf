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

