include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "kms" {
  config_path = "../kms"
}

dependency "eks" {
  config_path = "../eks"
}

locals {
  environment_config = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/valkey"
}

inputs = {
  project_name = include.root.locals.project_name
  environment  = local.environment_config.locals.environment

  vpc_id                     = dependency.vpc.outputs.vpc_id
  data_subnet_ids             = dependency.vpc.outputs.data_subnet_ids
  eks_node_security_group_id = dependency.eks.outputs.node_security_group_id
  kms_key_arn                 = dependency.kms.outputs.key_arns["valkey"]

  engine_version          = local.environment_config.locals.valkey_engine_version
  node_type               = local.environment_config.locals.valkey_node_type
  num_cache_clusters      = local.environment_config.locals.valkey_num_cache_clusters
  multi_az                = local.environment_config.locals.valkey_multi_az
  snapshot_retention_days = local.environment_config.locals.valkey_snapshot_retention_days
  log_retention_days      = local.environment_config.locals.valkey_log_retention_days
  apply_immediately       = local.environment_config.locals.valkey_apply_immediately
}
