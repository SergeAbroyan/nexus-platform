locals {
  account       = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals
  environment   = read_terragrunt_config(find_in_parent_folders("environment.hcl")).locals
  cluster       = local.environment.cluster
  operator_cidr = "${trimspace(run_cmd("--terragrunt-quiet", "curl", "-fsS", "https://checkip.amazonaws.com"))}/32"
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/cluster"
}

dependency "global" {
  config_path = "../../../global"
}

dependency "network" {
  config_path = "../network"
}

dependency "security" {
  config_path = "../security"
}

inputs = {
  kubernetes_version = local.cluster.kubernetes_version

  vpc_id             = dependency.network.outputs.vpc_id
  vpc_cidr_block     = dependency.network.outputs.vpc_cidr_block
  private_subnet_ids = dependency.network.outputs.private_subnet_ids
  node_subnet_ids    = dependency.network.outputs.workload_subnet_ids

  cluster_encryption_key_arn = dependency.security.outputs.kms_key_arns["eks"]
  ebs_encryption_key_arn     = dependency.security.outputs.kms_key_arns["ebs"]

  admin_principal_arns = concat(
    [for user_name in local.account.administrators.iam_user_names : "arn:aws:iam::${local.account.aws_account_id}:user/${user_name}"],
    [dependency.global.outputs.infrastructure_ci_role_arns[local.environment.environment]],
  )
  endpoint_public_access_cidrs = distinct(concat(local.account.administrators.cidrs, [local.operator_cidr]))

  deletion_protection              = local.cluster.deletion_protection
  control_plane_log_retention_days = local.cluster.control_plane_log_retention_days
  node_group                       = local.cluster.node_group
  karpenter                        = local.cluster.karpenter
  ingress_port                     = local.environment.ingress_port
}
