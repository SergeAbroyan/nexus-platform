data "cloudflare_zones" "active" {
  count = local.cloudflare_enabled ? 1 : 0

  account = { id = var.cloudflare.account_id }
  name    = var.domain_name
  status  = "active"
}

locals {
  admin_environments = local.cloudflare_enabled ? var.admin_access.environments : toset([])
  zone_active        = local.cloudflare_enabled && length(try(data.cloudflare_zones.active[0].result, [])) > 0

  admin_tools = {
    for pair in setproduct(local.admin_environments, keys(var.admin_access.tools)) :
    "${pair[0]}-${pair[1]}" => {
      environment = pair[0]
      tool        = pair[1]
      hostname    = "${pair[1]}-${pair[0]}.${var.domain_name}"
      service     = var.admin_access.tools[pair[1]]
    }
  }

  admin_applications = local.zone_active ? local.admin_tools : {}
}

resource "cloudflare_zero_trust_access_policy" "administrators" {
  count = local.cloudflare_enabled ? 1 : 0

  account_id       = var.cloudflare.account_id
  name             = "${var.name} administrators"
  decision         = "allow"
  session_duration = var.admin_access.session_duration

  include = [for email in var.cloudflare.access_emails : { email = { email = email } }]
}

resource "cloudflare_zero_trust_access_application" "admin" {
  for_each = local.admin_applications

  account_id                 = var.cloudflare.account_id
  name                       = "${var.name} ${each.value.environment} ${each.value.tool}"
  type                       = "self_hosted"
  domain                     = each.value.hostname
  destinations               = [{ type = "public", uri = each.value.hostname }]
  session_duration           = var.admin_access.session_duration
  app_launcher_visible       = true
  http_only_cookie_attribute = true

  policies = [{
    id         = cloudflare_zero_trust_access_policy.administrators[0].id
    precedence = 1
  }]
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "admin" {
  for_each = local.admin_environments

  account_id = var.cloudflare.account_id
  name       = "${var.name}-${each.key}-admin"
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "admin" {
  for_each = local.admin_environments

  account_id = var.cloudflare.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.admin[each.key].id

  config = {
    ingress = concat(
      [
        for key, application in local.admin_applications : {
          hostname = application.hostname
          service  = application.service
          origin_request = {
            access = {
              required  = true
              team_name = var.cloudflare.access_team
              aud_tag   = [cloudflare_zero_trust_access_application.admin[key].aud]
            }
          }
        } if application.environment == each.key
      ],
      [{ service = "http_status:404" }],
    )
  }
}

resource "cloudflare_dns_record" "admin" {
  for_each = local.admin_applications

  zone_id = cloudflare_zone.this[0].id
  name    = each.value.hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.admin[each.value.environment].id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
  comment = "${each.value.tool} in ${each.value.environment}, reached through Cloudflare Tunnel behind Access"

  depends_on = [cloudflare_zero_trust_tunnel_cloudflared_config.admin]
}

module "admin_tunnel_token" {
  source   = "terraform-aws-modules/secrets-manager/aws"
  version  = "2.2.0"
  for_each = local.admin_environments

  name                    = "${var.name}/cloudflare/${each.key}-tunnel-token"
  description             = "Token that cloudflared in the ${each.key} cluster uses to run the admin tunnel"
  recovery_window_in_days = 7
  replica                 = { (var.standby_region) = {} }

  secret_string         = "Replace this value with the token of the ${each.key} admin tunnel."
  ignore_secret_changes = true

  tags = merge(var.tags, { Name = "${var.name}-cloudflare-${each.key}-tunnel-token" })
}
