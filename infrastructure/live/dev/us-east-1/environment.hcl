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
    "eks",
    "rds",
    "redis",
    "sqs",
  ]

  kms_deletion_window_in_days = 7

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
}
