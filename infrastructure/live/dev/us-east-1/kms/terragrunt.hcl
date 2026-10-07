include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  environment_config = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/kms"
}

inputs = {
  project_name            = include.root.locals.project_name
  environment             = local.environment_config.locals.environment
  key_names               = local.environment_config.locals.kms_key_names
  deletion_window_in_days = local.environment_config.locals.kms_deletion_window_in_days
}
