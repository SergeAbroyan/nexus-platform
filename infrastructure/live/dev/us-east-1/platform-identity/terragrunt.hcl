include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "eks" {
  config_path = "../eks"
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
}
