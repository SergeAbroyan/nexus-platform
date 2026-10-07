include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  environment_config = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/vpc"
}

inputs = {
  project_name         = include.root.locals.project_name
  environment          = local.environment_config.locals.environment
  vpc_cidr             = local.environment_config.locals.vpc_cidr
  availability_zones   = local.environment_config.locals.availability_zones
  public_subnet_cidrs  = local.environment_config.locals.public_subnet_cidrs
  private_subnet_cidrs = local.environment_config.locals.private_subnet_cidrs
  data_subnet_cidrs    = local.environment_config.locals.data_subnet_cidrs
  nat_gateway_mode     = local.environment_config.locals.nat_gateway_mode

  enable_flow_logs                  = local.environment_config.locals.enable_flow_logs
  flow_log_retention_days           = local.environment_config.locals.flow_log_retention_days
  flow_log_max_aggregation_interval = local.environment_config.locals.flow_log_max_aggregation_interval
}
