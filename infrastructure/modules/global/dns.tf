locals {
  cloudflare_enabled = var.cloudflare != null
  cloudflare_serves  = local.cloudflare_enabled && try(var.cloudflare.dns_authoritative, false)
  route53_zone       = !local.cloudflare_serves || try(var.cloudflare.keep_route53_zone, false)
}

module "zone" {
  source  = "terraform-aws-modules/route53/aws"
  version = "6.5.1"
  count   = local.route53_zone ? 1 : 0

  name          = var.domain_name
  comment       = "Public DNS zone for ${var.name}"
  force_destroy = var.dns_force_destroy

  tags = merge(var.tags, { Name = var.domain_name })
}

moved {
  from = module.zone
  to   = module.zone[0]
}

resource "cloudflare_zone" "this" {
  count = local.cloudflare_enabled ? 1 : 0

  account = { id = var.cloudflare.account_id }
  name    = var.domain_name
  type    = "full"
}

resource "aws_route53domains_registered_domain" "this" {
  count = var.domain_registered_with_route53 ? 1 : 0

  domain_name = var.domain_name

  dynamic "name_server" {
    for_each = sort(local.cloudflare_serves ? cloudflare_zone.this[0].name_servers : module.zone[0].name_servers)

    content {
      name = name_server.value
    }
  }

  tags = merge(var.tags, { Name = var.domain_name })
}
