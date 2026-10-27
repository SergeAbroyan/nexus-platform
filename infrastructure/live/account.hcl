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
    deployment_branch         = "main"
  }

  dns_force_destroy         = true
  monthly_budget_amount_usd = 200

  ecr = {
    repository_names              = ["api", "worker"]
    force_delete                  = true
    untagged_image_retention_days = 7
    maximum_image_count           = 100
  }
}
