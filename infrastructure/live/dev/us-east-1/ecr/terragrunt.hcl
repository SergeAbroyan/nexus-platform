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
  source = "${get_repo_root()}/infrastructure/modules/ecr"
}

inputs = {
  project_name                  = include.root.locals.project_name
  environment                   = local.environment_config.locals.environment
  repository_names              = local.environment_config.locals.ecr_repository_names
  kms_key_arn                   = dependency.kms.outputs.key_arns["ecr"]
  force_delete                  = local.environment_config.locals.ecr_force_delete
  untagged_image_retention_days = local.environment_config.locals.ecr_untagged_image_retention_days
  maximum_image_count           = local.environment_config.locals.ecr_maximum_image_count
}
