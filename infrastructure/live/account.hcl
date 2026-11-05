locals {
  identity = read_terragrunt_config("${get_terragrunt_dir()}/identity.hcl").locals

  project_name   = "nexus"
  aws_account_id = local.identity.aws_account_id

  primary_region = "us-east-1"
  standby_region = "us-west-2"

  domain_name         = local.identity.domain_name
  alert_email_address = local.identity.alert_email_address
  administrators      = local.identity.administrators

  environments = ["dev", "staging", "production"]

  github = {
    owner                     = local.identity.github_owner
    infrastructure_repository = "nexus-platform"
    applications_repository   = "nexus-applications"
    gitops_repository         = "nexus-gitops"
    deployment_branch         = "main"
  }

  argocd_github_sso = {
    enabled      = false
    client_id    = ""
    admin_logins = local.identity.administrators.github_logins
  }

  guardduty_enabled    = false
  security_hub_enabled = false

  audit = {
    retention_days = 365
    force_destroy  = true
  }

  dns_force_destroy         = true
  monthly_budget_amount_usd = 200

  ecr = {
    repository_names    = ["api", "worker"]
    force_delete        = true
    maximum_image_count = 300
  }
}
