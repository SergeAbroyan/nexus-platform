locals {
  environment = read_terragrunt_config(find_in_parent_folders("environment.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/global"
}

inputs = {
  standby_region              = local.environment.standby_region
  domain_name                 = local.environment.domain_name
  dns_force_destroy           = local.environment.global.dns_force_destroy
  github                      = local.environment.github
  terraform_state_bucket_name = "${local.environment.project_name}-terraform-state-${local.environment.aws_account_id}"
  ecr                         = merge(local.environment.global.ecr, { namespace = local.environment.project_name })

  budget = {
    monthly_limit_usd  = local.environment.global.monthly_budget_amount_usd
    notification_email = local.environment.alert_email_address
  }
}
