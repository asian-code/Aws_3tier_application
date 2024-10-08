resource "aws_route53_zone" "main" {
  name = "hashstudiosllc.com"
}

#region Google Workspace MX records
resource "aws_route53_record" "google_mx_1" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "@"
  type    = "MX"
  ttl     = 300
  records = ["1 aspmx.l.google.com"]
}

resource "aws_route53_record" "google_mx_2" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "@"
  type    = "MX"
  ttl     = 300
  records = ["5 alt1.aspmx.l.google.com"]
}

resource "aws_route53_record" "google_mx_3" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "@"
  type    = "MX"
  ttl     = 300
  records = ["5 alt2.aspmx.l.google.com"]
}

resource "aws_route53_record" "google_mx_4" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "@"
  type    = "MX"
  ttl     = 300
  records = ["10 alt3.aspmx.l.google.com"]
}

resource "aws_route53_record" "google_mx_5" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "@"
  type    = "MX"
  ttl     = 300
  records = ["10 alt4.aspmx.l.google.com"]
}
#endregion
#region A Records
resource "aws_route53_record" "a_record_1" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "@"
  type    = "A"
  ttl     = 300
  records = ["198.185.159.144"]
}

resource "aws_route53_record" "a_record_2" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "@"
  type    = "A"
  ttl     = 300
  records = ["198.185.159.145"]
}

resource "aws_route53_record" "a_record_3" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "@"
  type    = "A"
  ttl     = 300
  records = ["198.49.23.144"]
}

resource "aws_route53_record" "a_record_4" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "@"
  type    = "A"
  ttl     = 300
  records = ["198.49.23.145"]
}

resource "aws_route53_record" "a_record_benefits" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "benefits"
  type    = "A"
  ttl     = 300
  records = ["18.221.254.179"]
}
#endregion
# CNAME Records
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

# TXT Records
resource "aws_route53_record" "txt_record_google_domainkey" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "google._domainkey"
  type    = "TXT"
  ttl     = 300
  records = [
    "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnW+N9XzyoR0dSs+1Hrb3ZxDHuLnCjPReRLJTEryfMshwHcfvRvDO1KrOEZ3dVSQplimzPSjLC5m53WXNCsWDeEhpyBopjwuGzK7h+dwrP9Ska++yomB4X9sxqaUcnEq1tzsyw5KwFGmAV3oA0bV/aHneDNSIWrGADO6reLi643mlwiZfDvsJcha16mqzX3uda+7I8zpOyRMtfxkLdZuCoOoc+51RpcsBx4iN2VIYhKcQkdgQou+bdfX9wkzHE+bJ0AW08hj/4ycOSbb/Yzw/kQZWeTKBBnudG9WlgCCZlLbmSz9ceMc3og2fVgHFit4Xuvt6oDwDxQyA8+WGUjwcCQIDAQAB"
  ]
}

resource "aws_route53_record" "txt_record_spf" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "@"
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:_spf.google.com ~all"]
}