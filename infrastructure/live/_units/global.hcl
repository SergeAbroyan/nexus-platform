locals {
  account = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/global"

  before_hook "cloudflare_token" {
    commands = local.account.cloudflare == null ? [] : ["apply", "destroy"]
    execute  = ["sh", "-c", "test -n \"$CLOUDFLARE_API_TOKEN\" || { echo 'Cloudflare is configured but CLOUDFLARE_API_TOKEN is not set in this shell; run: read -rs CLOUDFLARE_API_TOKEN && export CLOUDFLARE_API_TOKEN' >&2; exit 1; }"]
  }
}

inputs = {
  standby_region                 = local.account.standby_region
  domain_name                    = local.account.domain_name
  domain_registered_with_route53 = local.account.domain_registered_with_route53
  dns_force_destroy              = local.account.dns_force_destroy
  cloudflare                     = local.account.cloudflare
  admin_access                   = local.account.admin_access
  environments                   = local.account.environments
  github                         = local.account.github
  terraform_state_bucket_name    = "${local.account.project_name}-terraform-state-${local.account.aws_account_id}"
  ecr                            = merge(local.account.ecr, { namespace = local.account.project_name })
  guardduty_enabled              = local.account.guardduty_enabled
  security_hub_enabled           = local.account.security_hub_enabled
  audit                          = local.account.audit

  budget = {
    monthly_limit_usd  = local.account.monthly_budget_amount_usd
    notification_email = local.account.alert_email_address
  }
}
