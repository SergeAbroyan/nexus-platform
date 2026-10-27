terragrunt_version_constraint = ">= 1.1.5, < 2.0.0"
terraform_version_constraint  = ">= 1.10.0, < 2.0.0"

locals {
  environment = read_terragrunt_config(find_in_parent_folders("environment.hcl")).locals
  region      = try(read_terragrunt_config(find_in_parent_folders("region.hcl")).locals, {})

  aws_region = lookup(local.region, "aws_region", local.environment.primary_region)
  name = join("-", compact([
    local.environment.project_name,
    local.environment.environment,
    lookup(local.region, "region_code", ""),
  ]))

  tags = {
    Environment = local.environment.environment
    ManagedBy   = "Terraform"
    Project     = local.environment.project_name
  }
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket       = "${local.environment.project_name}-terraform-state-${local.environment.aws_account_id}"
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
      allowed_account_ids = ["${local.environment.aws_account_id}"]

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
