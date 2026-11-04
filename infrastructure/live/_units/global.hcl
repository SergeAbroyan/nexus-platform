locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/global"
}

inputs = {
  standby_region              = local.account.standby_region
  domain_name                 = local.account.domain_name
  dns_force_destroy           = local.account.dns_force_destroy
  environments                = local.account.environments
  github                      = local.account.github
  terraform_state_bucket_name = "${local.account.project_name}-terraform-state-${local.account.aws_account_id}"
  ecr                         = merge(local.account.ecr, { namespace = local.account.project_name })
  guardduty_enabled           = local.account.guardduty_enabled
  security_hub_enabled        = local.account.security_hub_enabled
  audit                       = local.account.audit

  budget = {
    monthly_limit_usd  = local.account.monthly_budget_amount_usd
    notification_email = local.account.alert_email_address
  }
}
