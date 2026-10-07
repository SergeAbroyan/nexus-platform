include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "ecr" {
  config_path = "../ecr"
}

locals {
  environment_config = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/ci-identity"
}

inputs = {
  project_name = include.root.locals.project_name
  environment  = local.environment_config.locals.environment

  github_owner             = local.environment_config.locals.github_owner
  infrastructure_repository = local.environment_config.locals.github_infrastructure_repository
  applications_repository   = local.environment_config.locals.github_applications_repository
  deployment_branch         = local.environment_config.locals.github_deployment_branch

  ecr_repository_arns        = values(dependency.ecr.outputs.repository_arns)
  terraform_state_bucket_name = include.root.locals.state_bucket_name
}
