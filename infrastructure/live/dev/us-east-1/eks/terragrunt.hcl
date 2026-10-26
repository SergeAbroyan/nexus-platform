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

dependency "ci_identity" {
  config_path = "../ci-identity"
}

locals {
  environment_config = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
  ci_runner_cidr     = get_env("CI_RUNNER_PUBLIC_ACCESS_CIDR", "")
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/eks"
}

inputs = {
  project_name       = include.root.locals.project_name
  environment        = local.environment_config.locals.environment
  kubernetes_version = local.environment_config.locals.kubernetes_version

  vpc_id             = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids

  cluster_encryption_key_arn = dependency.kms.outputs.key_arns["eks"]
  ebs_encryption_key_arn     = dependency.kms.outputs.key_arns["ebs"]

  cluster_admin_principal_arns = concat(
    [
      for user_name in local.environment_config.locals.eks_admin_user_names :
      "arn:aws:iam::${include.root.locals.aws_account_id}:user/${user_name}"
    ],
    [dependency.ci_identity.outputs.infrastructure_ci_iam_role_arn],
  )

  endpoint_public_access = local.environment_config.locals.eks_endpoint_public_access
  endpoint_public_access_cidrs = local.environment_config.locals.eks_endpoint_public_access ? compact([
    get_env("EKS_PUBLIC_ACCESS_CIDR", ""),
    local.ci_runner_cidr,
  ]) : []

  deletion_protection              = local.environment_config.locals.eks_deletion_protection
  control_plane_log_retention_days = local.environment_config.locals.eks_control_plane_log_retention_days
  node_group                       = local.environment_config.locals.eks_node_group
}
