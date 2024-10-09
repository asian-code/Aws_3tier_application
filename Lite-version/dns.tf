resource "aws_route53_zone" "main" {
  name = "hashstudiosllc.com"
}

#region Google Workspace MX records
resource "aws_route53_record" "google_mx" {
  zone_id = aws_route53_zone.main.zone_id
  name    = ""
  type    = "MX"
  ttl     = 300
  records = [
    "1 aspmx.l.google.com",
    "5 alt1.aspmx.l.google.com",
    "5 alt2.aspmx.l.google.com",
    "10 alt3.aspmx.l.google.com",
    "10 alt4.aspmx.l.google.com"
  ]
}
#endregion
#region A Records
resource "aws_route53_record" "a_records" {
  zone_id = aws_route53_zone.main.zone_id
  name    = ""
  type    = "A"
  ttl     = 300
  records = [
    "198.185.159.144",
    "198.185.159.145",
    "198.49.23.144",
    "198.49.23.145"
  ]
}
resource "aws_route53_record" "backend" { # point to alb that translates port 80 to 3000 for nodejs
  zone_id = aws_route53_zone.main.zone_id
  name    = "benefits-backend"
  type    = "A"
  records = [aws_instance.main.public_ip]  # Reference to EC2 instance's public IP
}
resource "aws_route53_record" "frontend" { # Point to cloudfront
  zone_id = aws_route53_zone.main.zone_id
  name    = "benefits" 
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name  # Reference to CloudFront distribution's domain name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id  # CloudFront hosted zone ID, same for all CloudFront distributions
    evaluate_target_health = false  # CloudFront doesn't support health checks
  }
}
#endregion
#region CNAME Records
resource "aws_route53_record" "cname_record_verify" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "dkdwjprh3eb9l9plffaf"
  type    = "CNAME"
  ttl     = 300
  records = ["verify.squarespace.com"]
}

resource "aws_route53_record" "cname_record_www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www"
  type    = "CNAME"
  ttl     = 300
  records = ["ext-cust.squarespace.com"]
}

resource "aws_route53_record" "cname_google_1" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "7tadbnmkpqyl"
  type    = "CNAME"
  ttl     = 300
  records = ["gv-yxyrv5vdjv57wq.dv.googlehosted.com"]
}

resource "aws_route53_record" "cname_google_2" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "cmrm4cbdcs4f"
  type    = "CNAME"
  ttl     = 300
  records = ["gv-jdepwkp7llxkrg.dv.googlehosted.com"]
}
#endregion

# TXT Records

# --- ADD THIS ONE MANUALLY ---!
# resource "aws_route53_record" "txt_record_google_domainkey" {
#   zone_id = aws_route53_zone.main.zone_id
#   name    = "google._domainkey"
#   type    = "TXT"
#   ttl     = 300
  # records = [
  #     "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnW+N9XzyoR0dSs+1Hrb3ZxDHuLnCjPReRLJT ",
  #     "EryfMshwHcfvRvDO1KrOEZ3dVSQplimzPSjLC5m53WXNCsWDeEhpyBopjwuGzK7h+dwrP9Ska++yomB4X9sxqaUcnEq1tz ",
  #     "syw5KwFGmAV3oA0bV/aHneDNSIWrGADO6reLi643mlwiZfDvsJcha16mqzX3uda+7I8zpOyRMtfxkLdZuCoOoc+51Rpcs ",
  #     "Bx4iN2VIYhKcQkdgQou+bdfX9wkzHE+bJ0AW08hj/4ycOSbb/Yzw/kQZWeTKBBnudG9WlgCCZlLbmSz9ceMc3og2fVgHF ",
  #     "it4Xuvt6oDwDxQyA8+WGUjwcCQIDAQAB"
  #   ]
# }

resource "aws_route53_record" "txt_record_spf" {
  zone_id = aws_route53_zone.main.zone_id
  name    = ""
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:_spf.google.com ~all"]
}
output "Route53_Nameservers" {
  value = aws_route53_zone.main.name_servers
}