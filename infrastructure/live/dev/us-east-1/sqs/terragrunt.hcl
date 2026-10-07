include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "kms" {
  config_path = "../kms"
}

locals {
  environment_config = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/sqs"
}

inputs = {
  project_name = include.root.locals.project_name
  environment  = local.environment_config.locals.environment
  kms_key_arn  = dependency.kms.outputs.key_arns["sqs"]

  visibility_timeout_seconds         = local.environment_config.locals.sqs_visibility_timeout_seconds
  message_retention_seconds          = local.environment_config.locals.sqs_message_retention_seconds
  dlq_message_retention_seconds      = local.environment_config.locals.sqs_dlq_message_retention_seconds
  receive_wait_time_seconds          = local.environment_config.locals.sqs_receive_wait_time_seconds
  max_receive_count                  = local.environment_config.locals.sqs_max_receive_count
  kms_data_key_reuse_period_seconds  = local.environment_config.locals.sqs_kms_data_key_reuse_period_seconds
}
