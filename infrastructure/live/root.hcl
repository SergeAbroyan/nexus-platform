locals {
  environment_config = read_terragrunt_config(find_in_parent_folders("environment.hcl"))

  project_name        = get_env("TG_PROJECT_NAME", "nexus")
  aws_account_id      = get_aws_account_id()
  state_bucket_name   = "${local.project_name}-terraform-state-${local.aws_account_id}"
  state_bucket_region = get_env("TG_STATE_BUCKET_REGION", "us-east-1")

  environment = local.environment_config.locals.environment
  aws_region  = local.environment_config.locals.aws_region
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket       = local.state_bucket_name
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.state_bucket_region
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
      region = "${local.aws_region}"

      default_tags {
        tags = {
          Environment = "${local.environment}"
          ManagedBy   = "Terraform"
          Project     = "${local.project_name}"
        }
      }
    }
  EOF
}
