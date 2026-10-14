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

dependency "kms" {
  config_path = "../kms"
}

dependency "ecr" {
  config_path = "../ecr"
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

dependency "platform_secrets" {
  config_path = "../platform-secrets"
}

dependency "dns" {
  config_path = "../dns"
}

dependency "notifications" {
  config_path = "../notifications"
}

dependencies {
  paths = [
    "../platform-identity",
    "../workload-identity",
  ]
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

  cluster_name                       = dependency.eks.outputs.cluster_name
  aws_region                         = include.root.locals.aws_region
  vpc_id                             = dependency.vpc.outputs.vpc_id
  karpenter_interruption_queue_name = dependency.karpenter.outputs.interruption_queue_name
  karpenter_node_iam_role_name       = dependency.karpenter.outputs.node_iam_role_name
  ebs_kms_key_arn                    = dependency.kms.outputs.key_arns["ebs"]

  environment          = local.environment_config.locals.environment
  dns_zone_name        = local.environment_config.locals.dns_zone_name
  nexus_ingress_host   = local.environment_config.locals.nexus_ingress_host
  nexus_certificate_arn = dependency.dns.outputs.certificate_arn
  ecr_registry_url    = dependency.ecr.outputs.registry_url
  database_host       = dependency.rds.outputs.address
  database_port       = dependency.rds.outputs.port
  database_name       = dependency.rds.outputs.database_name
  database_username   = dependency.rds.outputs.username
  database_secret_arn = dependency.rds.outputs.master_user_secret_arn
  grafana_admin_secret_arn = dependency.platform_secrets.outputs.grafana_admin_secret_arn
  alert_sns_topic_arn         = dependency.notifications.outputs.topic_arn
  alertmanager_service_account = local.environment_config.locals.alertmanager_service_account
  grafana_service_account      = local.environment_config.locals.grafana_service_account
  valkey_host          = dependency.valkey.outputs.primary_endpoint
  valkey_port          = dependency.valkey.outputs.port
  valkey_username      = dependency.valkey.outputs.application_user_name
  valkey_cache_name    = dependency.valkey.outputs.replication_group_id
  sqs_queue_url        = dependency.sqs.outputs.queue_url

  controller_resources        = local.environment_config.locals.argocd_controller_resources
  server_resources            = local.environment_config.locals.argocd_server_resources
  repository_server_resources = local.environment_config.locals.argocd_repository_server_resources
}
