include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "eks" {
  config_path = "../eks"
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "karpenter" {
  config_path = "../karpenter"
}

dependencies {
  paths = ["../platform-identity"]
}

locals {
  environment_config = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
}

generate "helm_provider" {
  path      = "helm-provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<-EOF
    provider "helm" {
      kubernetes = {
        host                   = "${dependency.eks.outputs.cluster_endpoint}"
        cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")

        exec = {
          api_version = "client.authentication.k8s.io/v1beta1"
          command     = "aws"
          args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${include.root.locals.aws_region}"]
        }
      }
    }
  EOF
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/argocd"
}

inputs = {
  chart_repository = local.environment_config.locals.argocd_chart_repository
  chart_version    = local.environment_config.locals.argocd_chart_version
  namespace        = local.environment_config.locals.argocd_namespace

  gitops_repository = local.environment_config.locals.gitops_repository
  gitops_revision   = local.environment_config.locals.gitops_revision
  gitops_chart_path = local.environment_config.locals.gitops_chart_path

  cluster_name                       = dependency.eks.outputs.cluster_name
  aws_region                         = include.root.locals.aws_region
  vpc_id                             = dependency.vpc.outputs.vpc_id
  karpenter_interruption_queue_name = dependency.karpenter.outputs.interruption_queue_name
  karpenter_node_iam_role_name       = dependency.karpenter.outputs.node_iam_role_name

  controller_resources        = local.environment_config.locals.argocd_controller_resources
  server_resources            = local.environment_config.locals.argocd_server_resources
  repository_server_resources = local.environment_config.locals.argocd_repository_server_resources
}
