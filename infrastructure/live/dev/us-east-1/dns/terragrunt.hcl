include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  environment_config = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/dns"
}

inputs = {
  project_name         = include.root.locals.project_name
  environment          = local.environment_config.locals.environment
  zone_name            = local.environment_config.locals.dns_zone_name
  force_destroy        = local.environment_config.locals.dns_force_destroy
}
