include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  environment_config = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
  enable_cdn          = local.environment_config.locals.enable_cdn
}

dependency "certificate" {
  config_path  = "../certificate"
  skip_outputs = !local.enable_cdn
}

dependencies {
  paths = ["../argocd"]
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/edge"
}

inputs = {
  project_name = include.root.locals.project_name
  environment  = local.environment_config.locals.environment

  enable_cdn_origin_mode = local.environment_config.locals.enable_cdn_origin_mode
  enable_cdn             = local.environment_config.locals.enable_cdn
  enable_waf             = local.environment_config.locals.enable_waf

  hostname        = local.environment_config.locals.nexus_ingress_host
  zone_name       = local.environment_config.locals.dns_zone_name
  certificate_arn = local.enable_cdn ? dependency.certificate.outputs.certificate_arn : ""

  origin_load_balancer_arn = local.environment_config.locals.cdn_origin_load_balancer_arn
  origin_domain_name       = local.environment_config.locals.cdn_origin_domain_name
  origin_http_port         = local.environment_config.locals.cdn_origin_http_port
  origin_https_port        = local.environment_config.locals.cdn_origin_https_port
  origin_protocol_policy   = local.environment_config.locals.cdn_origin_protocol_policy

  api_path_pattern                     = local.environment_config.locals.cdn_api_path_pattern
  price_class                          = local.environment_config.locals.cdn_price_class
  waf_rate_limit_per_five_minutes      = local.environment_config.locals.waf_rate_limit_per_five_minutes
}
