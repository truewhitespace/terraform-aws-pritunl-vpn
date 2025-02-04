# LoadBalancer Public
resource "aws_lb" "public" {
  name               = format("%s-public-lb", local.name)
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids

  tags = merge(
    { Name = format("%s-lb", local.name) },
    local.tags
  )
}

resource "aws_lb_target_group" "public" {
  count    = length(local.public_rule)
  name     = format("%s-public-%s", local.name, count.index)
  port     = local.public_rule[count.index].port
  protocol = local.public_rule[count.index].protocol
  vpc_id   = var.vpc_id

  health_check {
    port     = lookup(local.public_rule[count.index], "health_check_port", null)
    protocol = lookup(local.public_rule[count.index], "health_check_protocol", null)
  }
}

resource "aws_acm_certificate" "cert" {
  domain_name       = format("%s.%s", var.public_lb_vpn_domain, var.route53_zone_name)
  validation_method = "DNS"

  tags = {
    Environment = "all"
  }

  # subject_alternative_names = [format("%s.%s", var.public_lb_vpn_domain, var.route53_zone_name)]

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_acm_certificate_validation" "validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [format("%s.%s", var.public_lb_vpn_domain, var.route53_zone_name)] //[for record in aws_route53_record.public : record.fqdn]
}

resource "aws_lb_listener" "public" {
  count             = length(local.public_rule)
  load_balancer_arn = aws_lb.public.arn
  port              = local.public_rule[count.index].port
  protocol          = local.public_rule[count.index].protocol
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.public[count.index].arn
  }

  certificate_arn = aws_acm_certificate.cert.arn
}


# LoadBalancer Private
resource "aws_lb" "private" {
  count              = var.is_create_private_lb ? 1 : 0
  name               = format("%s-private-lb", local.name)
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids

  tags = merge(
    { Name = format("%s-lb", local.name) },
    local.tags
  )
}

resource "aws_lb_target_group" "private" {
  count              = var.is_create_private_lb ? length(local.private_rule) : 0
  name               = format("%s-private-%s", local.name, count.index)
  preserve_client_ip = false
  port               = local.private_rule[count.index].port
  protocol           = local.private_rule[count.index].protocol
  vpc_id             = var.vpc_id

  health_check {
    port     = lookup(local.private_rule[count.index], "health_check_port", null)
    protocol = lookup(local.private_rule[count.index], "health_check_protocol", null)
  }
}

resource "aws_lb_listener" "private" {
  count             = var.is_create_private_lb ? length(local.private_rule) : 0
  load_balancer_arn = aws_lb.private[0].arn
  port              = local.private_rule[count.index].port
  protocol          = local.private_rule[count.index].protocol

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.private[count.index].arn
  }
}
