locals {
  name                   = "${var.project_name}-${var.environment}-valkey"
  application_user_name  = "${var.project_name}-${var.environment}-api"
  parameter_group_family = "valkey${split(".", var.engine_version)[0]}"

  standard_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  })
}

module "user_group" {
  source  = "terraform-aws-modules/elasticache/aws//modules/user-group"
  version = "1.11.1"

  engine        = "valkey"
  user_group_id = "${local.name}-users"

  default_user = {
    user_id       = "${local.name}-default"
    access_string = "off ~* -@all"
    engine        = "valkey"
    passwords     = [sha256("${local.name}-disabled-default-user")]
  }

  users = {
    (local.application_user_name) = {
      access_string = "on ~nexus:* -@all +@read +@write -@dangerous +ping +hello"
      engine        = "valkey"
      authentication_mode = {
        type = "iam"
      }
    }
  }

  tags = local.standard_tags
}

module "cache" {
  source  = "terraform-aws-modules/elasticache/aws"
  version = "1.11.1"

  replication_group_id = local.name
  description          = "Nexus ${var.environment} application cache"

  engine         = "valkey"
  engine_version = var.engine_version
  node_type      = var.node_type
  port           = 6379

  num_cache_clusters         = var.num_cache_clusters
  multi_az_enabled           = var.multi_az
  automatic_failover_enabled = var.multi_az

  at_rest_encryption_enabled = true
  kms_key_arn                = var.kms_key_arn
  transit_encryption_enabled = true
  transit_encryption_mode    = "required"
  user_group_ids             = [module.user_group.group_id]

  vpc_id                     = var.vpc_id
  security_group_name        = local.name
  security_group_description = "Valkey access from Nexus EKS worker nodes"
  security_group_rules = {
    valkey_from_eks = {
      type                         = "ingress"
      description                  = "Valkey from EKS worker nodes"
      from_port                    = 6379
      to_port                      = 6379
      ip_protocol                  = "tcp"
      referenced_security_group_id = var.eks_node_security_group_id
    }
  }

  subnet_group_name        = local.name
  subnet_group_description = "Private data subnets for ${local.name}"
  subnet_ids               = var.data_subnet_ids

  create_parameter_group      = true
  parameter_group_name        = local.name
  parameter_group_family      = local.parameter_group_family
  parameter_group_description = "Parameters for ${local.name}"
  parameters = [
    {
      name  = "latency-tracking"
      value = "yes"
    },
  ]

  snapshot_retention_limit = var.snapshot_retention_days
  snapshot_window          = "02:00-03:00"
  maintenance_window       = "sun:03:00-sun:04:00"

  auto_minor_version_upgrade = true
  apply_immediately          = var.apply_immediately

  log_delivery_configuration = {
    engine-log = {
      destination_type                       = "cloudwatch-logs"
      log_format                             = "json"
      cloudwatch_log_group_retention_in_days = var.log_retention_days
    }
    slow-log = {
      destination_type                       = "cloudwatch-logs"
      log_format                             = "json"
      cloudwatch_log_group_retention_in_days = var.log_retention_days
    }
  }

  tags = local.standard_tags
}
