include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "eks" {
  config_path = "../eks"
}

dependency "kms" {
  config_path = "../kms"
}

dependency "sqs" {
  config_path = "../sqs"
}

dependency "valkey" {
  config_path = "../valkey"
}

locals {
  environment_config = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/workload-identity"
}

inputs = {
  project_name = include.root.locals.project_name
  environment  = local.environment_config.locals.environment
  cluster_name = dependency.eks.outputs.cluster_name

  namespace              = local.environment_config.locals.application_namespace
  api_service_account    = local.environment_config.locals.api_service_account
  worker_service_account = local.environment_config.locals.worker_service_account

  sqs_queue_arn                = dependency.sqs.outputs.queue_arn
  sqs_kms_key_arn              = dependency.kms.outputs.key_arns["sqs"]
  valkey_replication_group_arn = dependency.valkey.outputs.replication_group_arn
  valkey_user_arn              = dependency.valkey.outputs.application_user_arn
}
