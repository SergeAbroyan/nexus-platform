include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "kms" {
  config_path = "../kms"
}

locals {
  environment_config = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/platform-secrets"
}

inputs = {
  project_name            = include.root.locals.project_name
  environment             = local.environment_config.locals.environment
  kms_key_arn             = dependency.kms.outputs.key_arns["secrets"]
  recovery_window_in_days = local.environment_config.locals.platform_secret_recovery_window_days
}
