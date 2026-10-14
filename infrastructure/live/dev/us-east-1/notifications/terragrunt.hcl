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
  source = "${get_repo_root()}/infrastructure/modules/notifications"
}

inputs = {
  project_name        = include.root.locals.project_name
  environment         = local.environment_config.locals.environment
  alert_email_address = local.environment_config.locals.alert_email_address
  kms_key_arn         = dependency.kms.outputs.key_arns["sns"]
}
