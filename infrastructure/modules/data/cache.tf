locals {
  cache_name             = "${var.name}-valkey"
  cache_user_name        = "${var.name}-api"
  parameter_group_family = "valkey${split(".", var.cache.engine_version)[0]}"
}

module "cache_users" {
  source  = "terraform-aws-modules/elasticache/aws//modules/user-group"
  version = "1.11.2"

  engine        = "valkey"
  user_group_id = "${local.cache_name}-users"

  default_user = {
    user_id       = "${local.cache_name}-default"
    access_string = "off ~* -@all"
    engine        = "valkey"
    passwords     = [sha256("${local.cache_name}-disabled-default-user")]
  }

  users = {
    (local.cache_user_name) = {
      access_string = "on ~nexus:* -@all +@read +@write -@dangerous +ping +hello"
      engine        = "valkey"
      authentication_mode = {
        type = "iam"
      }
    }
  }

  tags = var.tags
}

module "cache" {
  source  = "terraform-aws-modules/elasticache/aws"
  version = "1.11.2"

  replication_group_id = local.cache_name
  description          = "Nexus application cache for ${var.name}"

  engine         = "valkey"
  engine_version = var.cache.engine_version
  node_type      = var.cache.node_type
  port           = 6379

  num_cache_clusters          = var.cache.num_cache_clusters
  preferred_cache_cluster_azs = [for index in range(var.cache.num_cache_clusters) : var.availability_zones[index % length(var.availability_zones)]]
  multi_az_enabled            = var.cache.multi_az
  automatic_failover_enabled  = var.cache.multi_az

  at_rest_encryption_enabled = true
  kms_key_arn                = var.kms_key_arns["valkey"]
  transit_encryption_enabled = true
  transit_encryption_mode    = "required"
  user_group_ids             = [module.cache_users.group_id]

  vpc_id                     = var.vpc_id
  security_group_name        = local.cache_name
  security_group_description = "Valkey access from Nexus EKS nodes"
  security_group_rules = {
    valkey_from_eks = {
      type                         = "ingress"
      description                  = "Valkey from EKS nodes"
      from_port                    = 6379
      to_port                      = 6379
      ip_protocol                  = "tcp"
      referenced_security_group_id = var.client_security_group_id
    }
  }

  subnet_group_name        = local.cache_name
  subnet_group_description = "Private data subnets for ${local.cache_name}"
  subnet_ids               = var.data_subnet_ids

  create_parameter_group      = true
  parameter_group_name        = local.cache_name
  parameter_group_family      = local.parameter_group_family
  parameter_group_description = "Parameters for ${local.cache_name}"
  parameters = [
    {
      name  = "latency-tracking"
      value = "yes"
    },
  ]

  snapshot_retention_limit = var.cache.snapshot_retention_days
  snapshot_window          = "02:00-03:00"
  maintenance_window       = "sun:03:00-sun:04:00"

  auto_minor_version_upgrade = true
  apply_immediately          = var.cache.apply_immediately

  log_delivery_configuration = {
    engine-log = {
      destination_type                       = "cloudwatch-logs"
      log_format                             = "json"
      cloudwatch_log_group_retention_in_days = var.cache.log_retention_days
    }
    slow-log = {
      destination_type                       = "cloudwatch-logs"
      log_format                             = "json"
      cloudwatch_log_group_retention_in_days = var.cache.log_retention_days
    }
  }

  tags = var.tags
}
