locals {
  environment = read_terragrunt_config(find_in_parent_folders("environment.hcl")).locals
  region      = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals
  standby     = local.region.aws_region != local.environment.primary_region
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/data"
}

dependency "network" {
  config_path = "../network"
}

dependency "security" {
  config_path = "../security"
}

dependency "cluster" {
  config_path = "../cluster"
}

dependency "primary" {
  config_path = "../../${local.environment.primary_region}/data"
  enabled     = local.standby
}

inputs = {
  vpc_id                   = dependency.network.outputs.vpc_id
  data_subnet_ids          = dependency.network.outputs.data_subnet_ids
  client_security_group_id = dependency.cluster.outputs.node_security_group_id
  kms_key_arns             = dependency.security.outputs.kms_key_arns
  alert_topic_arn          = dependency.security.outputs.alert_topic_arn

  database = local.environment.data.database
  cache    = local.environment.data.cache
  queue    = local.environment.data.queue
  alarms   = local.environment.data.alarms

  replication_source = local.standby ? {
    db_instance_arn                = dependency.primary.outputs.database_arn
    master_user_secret_arn         = dependency.primary.outputs.database_secret_arn
    master_user_secret_kms_key_arn = dependency.primary.outputs.database_secret_kms_key_arn
  } : null
  promote_replica = local.region.aws_region == local.environment.active_region
}
