locals {
  environment = read_terragrunt_config(find_in_parent_folders("environment.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/edge"
}

dependency "global" {
  config_path = "../global"
}

dependency "primary_platform" {
  config_path = "../${local.environment.primary_region}/platform"
}

dependency "standby_platform" {
  config_path = "../${local.environment.standby_region}/platform"
}

inputs = {
  region        = local.environment.primary_region
  zone_id       = dependency.global.outputs.zone_id
  zone_name     = local.environment.domain_name
  hostname      = "${local.environment.application_subdomain}.${local.environment.domain_name}"
  active_region = local.environment.active_region

  origins = {
    (local.environment.primary_region) = {
      load_balancer_arn = dependency.primary_platform.outputs.ingress_load_balancer_arn
      domain_name       = dependency.primary_platform.outputs.ingress_load_balancer_dns_name
    }
    (local.environment.standby_region) = {
      load_balancer_arn = dependency.standby_platform.outputs.ingress_load_balancer_arn
      domain_name       = dependency.standby_platform.outputs.ingress_load_balancer_dns_name
    }
  }

  price_class                     = local.environment.edge.price_class
  waf_rate_limit_per_five_minutes = local.environment.edge.waf_rate_limit_per_five_minutes
}
