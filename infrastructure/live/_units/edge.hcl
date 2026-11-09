locals {
  account     = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals
  environment = read_terragrunt_config(find_in_parent_folders("environment.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/edge"

  before_hook "cloudflare_token" {
    commands = local.account.cloudflare == null ? [] : ["plan", "apply", "destroy"]
    execute  = ["sh", "-c", "test -n \"$CLOUDFLARE_API_TOKEN\" || { echo 'Cloudflare is configured but CLOUDFLARE_API_TOKEN is not set in this shell; run: read -rs CLOUDFLARE_API_TOKEN && export CLOUDFLARE_API_TOKEN' >&2; exit 1; }"]
  }
}

dependency "global" {
  config_path = "../../global"
}

dependency "primary_platform" {
  config_path = "../${local.account.primary_region}/platform"
}

dependency "standby_platform" {
  config_path = "../${local.account.standby_region}/platform"
  enabled     = local.environment.standby_enabled
}

inputs = {
  region             = local.account.primary_region
  zone_id            = try(dependency.global.outputs.zone_id, null)
  zone_name          = local.account.domain_name
  cloudflare_zone_id = try(dependency.global.outputs.cloudflare_zone_id, null)
  hostname           = "${local.environment.application_subdomain}.${local.account.domain_name}"
  active_region      = local.environment.active_region

  origins = {
    for region, origin in {
      (local.account.primary_region) = {
        load_balancer_arn = dependency.primary_platform.outputs.ingress_load_balancer_arn
        domain_name       = dependency.primary_platform.outputs.ingress_load_balancer_dns_name
        http_port         = dependency.primary_platform.outputs.ingress_origin_port
      }
      (local.account.standby_region) = local.environment.standby_enabled ? {
        load_balancer_arn = dependency.standby_platform.outputs.ingress_load_balancer_arn
        domain_name       = dependency.standby_platform.outputs.ingress_load_balancer_dns_name
        http_port         = dependency.standby_platform.outputs.ingress_origin_port
      } : null
    } : region => origin if origin != null
  }

  price_class                     = local.environment.edge.price_class
  waf_rate_limit_per_five_minutes = local.environment.edge.waf_rate_limit_per_five_minutes
}
