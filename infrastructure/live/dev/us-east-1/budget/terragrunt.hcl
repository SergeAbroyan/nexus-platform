include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  environment_config = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/budget"
}

inputs = {
  project_name       = include.root.locals.project_name
  environment        = local.environment_config.locals.environment
  monthly_limit_usd  = local.environment_config.locals.monthly_budget_amount_usd
  notification_email = local.environment_config.locals.alert_email_address
}
