data "aws_route53_zone" "this" {
  count = var.is_create_route53_reccord ? 1 : 0
  name  = var.route53_zone_name
}

resource "aws_route53_record" "public" {
  # count   = var.is_create_route53_reccord ? 1 : 0
  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = format("%s.%s", var.public_lb_vpn_domain, var.route53_zone_name)
  type    = "A"
  alias {
    name                   = aws_lb.public.dns_name
    zone_id                = aws_lb.public.zone_id
    evaluate_target_health = true
  }

  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
}

resource "aws_route53_record" "private" {
  count   = var.is_create_private_lb && var.is_create_route53_reccord ? 1 : 0
  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = format("%s.%s", var.private_lb_vpn_domain, var.route53_zone_name)
  type    = "A"
  alias {
    name                   = aws_lb.private[0].dns_name
    zone_id                = aws_lb.private[0].zone_id
    evaluate_target_health = true
  }
}
