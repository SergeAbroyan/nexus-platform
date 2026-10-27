locals {
  account     = read_terragrunt_config(find_in_parent_folders("account.hcl")).locals
  environment = read_terragrunt_config(find_in_parent_folders("environment.hcl")).locals
  region      = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/platform"
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

dependency "data" {
  config_path = "../data"
}

generate "helm_provider" {
  path      = "helm-provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<-EOF
    variable "cluster_endpoint" {
      description = "EKS API endpoint used by the Helm provider."
      type        = string
      nullable    = false
    }

    variable "cluster_certificate_authority_data" {
      description = "Base64-encoded EKS cluster CA certificate used by the Helm provider."
      type        = string
      nullable    = false
    }

    provider "helm" {
      kubernetes = {
        host                   = var.cluster_endpoint
        cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)

        exec = {
          api_version = "client.authentication.k8s.io/v1beta1"
          command     = "aws"
          args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
        }
      }
    }
  EOF
}

inputs = {
  region      = local.region.aws_region
  environment = local.environment.environment

  cluster_name                       = dependency.cluster.outputs.cluster_name
  cluster_endpoint                   = dependency.cluster.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.cluster.outputs.cluster_certificate_authority_data

  vpc_id                   = dependency.network.outputs.vpc_id
  vpc_cidr_block           = dependency.network.outputs.vpc_cidr_block
  load_balancer_subnet_ids = dependency.network.outputs.workload_subnet_ids

  karpenter = {
    node_iam_role_name      = dependency.cluster.outputs.karpenter_node_iam_role_name
    interruption_queue_name = dependency.cluster.outputs.karpenter_interruption_queue_name
    replicas                = local.environment.platform.karpenter_replicas
  }

  kms_key_arns             = dependency.security.outputs.kms_key_arns
  grafana_admin_secret_arn = dependency.security.outputs.grafana_admin_secret_arn
  alert_topic_arn          = dependency.security.outputs.alert_topic_arn

  database = {
    host               = dependency.data.outputs.database_address
    port               = dependency.data.outputs.database_port
    name               = dependency.data.outputs.database_name
    username           = dependency.data.outputs.database_username
    secret_arn         = dependency.data.outputs.database_secret_arn
    secret_kms_key_arn = dependency.data.outputs.database_secret_kms_key_arn
  }

  cache = {
    host                  = dependency.data.outputs.cache_primary_endpoint
    port                  = dependency.data.outputs.cache_port
    username              = dependency.data.outputs.cache_user_name
    user_arn              = dependency.data.outputs.cache_user_arn
    replication_group_id  = dependency.data.outputs.cache_replication_group_id
    replication_group_arn = dependency.data.outputs.cache_replication_group_arn
  }

  queue = {
    url = dependency.data.outputs.queue_url
    arn = dependency.data.outputs.queue_arn
  }

  ecr_registry                      = "${local.account.aws_account_id}.dkr.ecr.${local.region.aws_region}.amazonaws.com"
  application_hostname              = "${local.environment.application_subdomain}.${local.account.domain_name}"
  ingress_port                      = local.environment.ingress_port
  load_balancer_deletion_protection = local.environment.platform.load_balancer_deletion_protection
  argocd                            = local.environment.platform.argocd
  gitops                            = local.environment.platform.gitops
}
