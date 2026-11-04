locals {
  project_name   = "nexus"
  aws_account_id = "123456789012"

  primary_region = "us-east-1"
  standby_region = "us-west-2"

  domain_name         = ""
  alert_email_address = "alerts@example.com"

  environments = ["dev", "staging", "production"]

  github = {
    owner                     = "SergeAbroyan"
    infrastructure_repository = "nexus-platform"
    applications_repository   = "nexus-applications"
    gitops_repository         = "nexus-gitops"
    deployment_branch         = "main"
  }

  argocd_github_sso = {
    enabled      = false
    client_id    = ""
    admin_logins = ["SergeAbroyan"]
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
