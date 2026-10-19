include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "dns" {
  config_path = "../dns"
}

locals {
  environment_config = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/certificate"
}

inputs = {
  project_name         = include.root.locals.project_name
  environment          = local.environment_config.locals.environment
  application_hostname = local.environment_config.locals.nexus_ingress_host
  zone_id              = dependency.dns.outputs.zone_id
}
