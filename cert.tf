resource "aws_acm_certificate" "vpn_cert" {
  domain_name       = "vpn.barneyparker.com"
  validation_method = "DNS"
}

resource "aws_route53_record" "vpn_cert_validation" {
  provider = aws.dns

  for_each = {
    for dvo in aws_acm_certificate.vpn_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.domain.zone_id
}

resource "aws_acm_certificate_validation" "vpn_cert" {
  certificate_arn         = aws_acm_certificate.vpn_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.vpn_cert_validation : record.fqdn]
}