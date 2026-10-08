locals {
  environment = "dev"
  aws_region  = "us-east-1"

  vpc_cidr = "10.10.0.0/16"

  availability_zones = [
    "us-east-1a",
    "us-east-1b",
    "us-east-1c",
  ]

  public_subnet_cidrs = [
    "10.10.0.0/24",
    "10.10.1.0/24",
    "10.10.2.0/24",
  ]

  private_subnet_cidrs = [
    "10.10.16.0/20",
    "10.10.32.0/20",
    "10.10.48.0/20",
  ]

  data_subnet_cidrs = [
    "10.10.64.0/24",
    "10.10.65.0/24",
    "10.10.66.0/24",
  ]

  nat_gateway_mode                  = "single"
  enable_flow_logs                  = true
  flow_log_retention_days           = 7
  flow_log_max_aggregation_interval = 60

  kms_key_names = [
    "ebs",
    "eks",
    "rds",
    "redis",
    "secrets",
    "sqs",
  ]

  kms_deletion_window_in_days = 7

  platform_secret_recovery_window_days = 7

  ecr_repository_names = [
    "api",
    "frontend",
    "worker",
  ]

  ecr_force_delete                  = true
  ecr_untagged_image_retention_days = 7
  ecr_maximum_image_count           = 20

  kubernetes_version                   = "1.35"
  eks_endpoint_public_access           = true
  eks_deletion_protection              = false
  eks_control_plane_log_retention_days = 7

  eks_node_group = {
    instance_types = ["t3.large"]
    capacity_type  = "ON_DEMAND"
    min_size       = 1
    max_size       = 2
    desired_size   = 1
    disk_size      = 30
  }

  karpenter_namespace                = "kube-system"
  karpenter_service_account          = "karpenter"
  karpenter_enable_spot_interruption = true

  rds_database_name         = "nexus"
  rds_master_username       = "nexus_admin"
  rds_engine_version        = "17"
  rds_instance_class        = "db.t4g.micro"
  rds_allocated_storage     = 20
  rds_max_allocated_storage = 100
  rds_multi_az              = false
  rds_backup_retention_days = 7
  rds_deletion_protection   = false
  rds_skip_final_snapshot   = true
  rds_apply_immediately     = true

  valkey_engine_version          = "8.1"
  valkey_node_type               = "cache.t4g.micro"
  valkey_num_cache_clusters      = 1
  valkey_multi_az                = false
  valkey_snapshot_retention_days = 1
  valkey_log_retention_days      = 7
  valkey_apply_immediately       = true

  sqs_visibility_timeout_seconds        = 60
  sqs_message_retention_seconds         = 345600
  sqs_dlq_message_retention_seconds     = 1209600
  sqs_receive_wait_time_seconds         = 20
  sqs_max_receive_count                 = 5
  sqs_kms_data_key_reuse_period_seconds = 300

  application_namespace  = "nexus"
  api_service_account    = "api"
  worker_service_account = "worker"

  load_balancer_controller_namespace       = "kube-system"
  load_balancer_controller_service_account = "aws-load-balancer-controller"

  external_secrets_namespace       = "external-secrets"
  external_secrets_service_account = "external-secrets"

  argocd_namespace        = "argocd"
  argocd_chart_repository = "https://argoproj.github.io/argo-helm"
  argocd_chart_version    = "10.9.6"

  gitops_repository = "https://github.com/SergeAbroyan/nexus-gitops.git"
  gitops_revision   = "main"

  argocd_controller_resources = {
    requests = {
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }

  argocd_server_resources = {
    requests = {
      cpu    = "50m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "256Mi"
    }
  }

  argocd_repository_server_resources = {
    requests = {
      cpu    = "50m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "300m"
      memory = "256Mi"
    }
  }

  github_owner                     = "SergeAbroyan"
  github_infrastructure_repository = "nexus-platform"
  github_applications_repository   = "nexus-applications"
  github_deployment_branch         = "main"
}
