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
  source = "${get_repo_root()}/infrastructure/modules/rds"
}

inputs = {
  project_name = include.root.locals.project_name
  environment  = local.environment_config.locals.environment

  vpc_id                     = dependency.vpc.outputs.vpc_id
  data_subnet_ids            = dependency.vpc.outputs.data_subnet_ids
  eks_node_security_group_id = dependency.eks.outputs.node_security_group_id
  kms_key_arn                = dependency.kms.outputs.key_arns["rds"]

  database_name         = local.environment_config.locals.rds_database_name
  master_username       = local.environment_config.locals.rds_master_username
  engine_version        = local.environment_config.locals.rds_engine_version
  instance_class        = local.environment_config.locals.rds_instance_class
  allocated_storage     = local.environment_config.locals.rds_allocated_storage
  max_allocated_storage = local.environment_config.locals.rds_max_allocated_storage
  multi_az              = local.environment_config.locals.rds_multi_az
  backup_retention_days = local.environment_config.locals.rds_backup_retention_days
  deletion_protection   = local.environment_config.locals.rds_deletion_protection
  skip_final_snapshot   = local.environment_config.locals.rds_skip_final_snapshot
  apply_immediately     = local.environment_config.locals.rds_apply_immediately
}
