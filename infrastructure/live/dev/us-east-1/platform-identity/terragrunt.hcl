include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "eks" {
  config_path = "../eks"
}

dependency "kms" {
  config_path = "../kms"
}

dependency "rds" {
  config_path = "../rds"
}

dependency "platform_secrets" {
  config_path = "../platform-secrets"
}

dependency "dns" {
  config_path = "../dns"
}

locals {
  environment_config = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/platform-identity"
}

inputs = {
  project_name = include.root.locals.project_name
  environment  = local.environment_config.locals.environment
  cluster_name = dependency.eks.outputs.cluster_name

  load_balancer_controller_namespace       = local.environment_config.locals.load_balancer_controller_namespace
  load_balancer_controller_service_account = local.environment_config.locals.load_balancer_controller_service_account

  external_secrets_namespace       = local.environment_config.locals.external_secrets_namespace
  external_secrets_service_account = local.environment_config.locals.external_secrets_service_account
  external_dns_namespace           = local.environment_config.locals.external_dns_namespace
  external_dns_service_account     = local.environment_config.locals.external_dns_service_account
  external_dns_hosted_zone_arn     = dependency.dns.outputs.zone_arn
  rds_master_user_secret_arn       = dependency.rds.outputs.master_user_secret_arn
  rds_kms_key_arn                  = dependency.kms.outputs.key_arns["rds"]
  additional_secret_arns           = [dependency.platform_secrets.outputs.grafana_admin_secret_arn]
  additional_secret_kms_key_arns   = [dependency.kms.outputs.key_arns["secrets"]]
}
