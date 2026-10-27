terragrunt_version_constraint = ">= 1.1.5, < 2.0.0"
terraform_version_constraint  = ">= 1.11.0, < 2.0.0"

locals {
  account     = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals
  environment = try(read_terragrunt_config(find_in_parent_folders("environment.hcl")).locals, {})
  region      = try(read_terragrunt_config(find_in_parent_folders("region.hcl")).locals, {})

  aws_region = lookup(local.region, "aws_region", local.account.primary_region)
  enabled    = local.aws_region != local.account.standby_region || lookup(local.environment, "standby_enabled", false)

  name = join("-", compact([
    local.account.project_name,
    lookup(local.environment, "environment", ""),
    lookup(local.region, "region_code", ""),
  ]))

  tags = {
    Environment = lookup(local.environment, "environment", "shared")
    ManagedBy   = "Terraform"
    Project     = local.account.project_name
  }
}

exclude {
  if      = !local.enabled
  actions = ["all"]
}

terraform {
  before_hook "region_disabled" {
    commands = local.enabled ? [] : ["plan", "apply"]
    execute  = ["sh", "-c", "echo 'This region is disabled for this environment; set standby_enabled = true in environment.hcl to use it.' >&2; exit 1"]
  }
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket       = "${local.account.project_name}-terraform-state-${local.account.aws_account_id}"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true

    disable_bucket_update = true
  }
}

generate "aws_provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<-EOF
    provider "aws" {
      region              = "${local.aws_region}"
      allowed_account_ids = ["${local.account.aws_account_id}"]

      default_tags {
        tags = {
          Environment = "${local.tags.Environment}"
          ManagedBy   = "${local.tags.ManagedBy}"
          Project     = "${local.tags.Project}"
        }
      }
    }
  EOF
}

inputs = {
  name = local.name
  tags = local.tags
}
