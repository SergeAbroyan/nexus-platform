locals {
  environment = read_terragrunt_config(find_in_parent_folders("environment.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/security"
}

inputs = {
  kms                            = local.environment.security.kms
  secret_recovery_window_in_days = local.environment.security.secret_recovery_window_in_days
  alert_email_address            = local.environment.alert_email_address
}
