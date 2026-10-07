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

locals {
  environment_config = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
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

  cluster_admin_principal_arns = [get_aws_caller_identity_arn()]

  endpoint_public_access       = local.environment_config.locals.eks_endpoint_public_access
  endpoint_public_access_cidrs = local.environment_config.locals.eks_endpoint_public_access ? [get_env("EKS_PUBLIC_ACCESS_CIDR")] : []

  deletion_protection              = local.environment_config.locals.eks_deletion_protection
  control_plane_log_retention_days = local.environment_config.locals.eks_control_plane_log_retention_days
  node_group                       = local.environment_config.locals.eks_node_group
}
