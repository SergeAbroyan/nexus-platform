include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "notifications" {
  config_path = "../notifications"
}

dependency "rds" {
  config_path = "../rds"
}

dependency "valkey" {
  config_path = "../valkey"
}

dependency "sqs" {
  config_path = "../sqs"
}

locals {
  environment_config = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/alarms"
}

inputs = {
  project_name                   = include.root.locals.project_name
  environment                    = local.environment_config.locals.environment
  notification_topic_arn         = dependency.notifications.outputs.topic_arn
  rds_identifier                 = dependency.rds.outputs.identifier
  valkey_member_cluster_ids      = dependency.valkey.outputs.member_cluster_ids
  sqs_queue_name                 = dependency.sqs.outputs.queue_name
  sqs_dead_letter_queue_name     = dependency.sqs.outputs.dead_letter_queue_name
  period_seconds                 = local.environment_config.locals.alarm_period_seconds
  evaluation_periods             = local.environment_config.locals.alarm_evaluation_periods
  rds_cpu_threshold_percent      = local.environment_config.locals.rds_cpu_alarm_threshold_percent
  rds_free_storage_threshold_bytes = local.environment_config.locals.rds_free_storage_alarm_threshold_bytes
  valkey_memory_threshold_percent  = local.environment_config.locals.valkey_memory_alarm_threshold_percent
  sqs_oldest_message_threshold_seconds = local.environment_config.locals.sqs_oldest_message_alarm_threshold_seconds
}
