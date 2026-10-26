locals {
  name                 = "${var.project_name}-${var.environment}-postgres"
  major_engine_version = split(".", var.engine_version)[0]

  standard_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  })
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"

  name            = local.name
  use_name_prefix = false
  description     = "PostgreSQL access from Nexus EKS worker nodes"
  vpc_id          = var.vpc_id

  ingress_rules = {
    postgresql_from_eks = {
      description                  = "PostgreSQL from EKS worker nodes"
      from_port                    = 5432
      to_port                      = 5432
      ip_protocol                  = "tcp"
      referenced_security_group_id = var.eks_node_security_group_id
    }
  }

  egress_rules = {}

  tags = merge(local.standard_tags, {
    Name = local.name
  })
}

module "database" {
  source  = "terraform-aws-modules/rds/aws"
  version = "7.2.0"

  identifier = local.name

  engine               = "postgres"
  engine_version       = var.engine_version
  major_engine_version = local.major_engine_version
  family               = "postgres${local.major_engine_version}"
  instance_class       = var.instance_class

  db_name  = var.database_name
  username = var.master_username
  port     = 5432

  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_key_arn

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  multi_az               = var.multi_az
  publicly_accessible    = false
  vpc_security_group_ids = [module.security_group.id]

  create_db_subnet_group          = true
  db_subnet_group_name            = local.name
  db_subnet_group_use_name_prefix = false
  subnet_ids                      = var.data_subnet_ids

  create_db_parameter_group       = true
  parameter_group_name            = local.name
  parameter_group_use_name_prefix = false
  parameters = [
    {
      name         = "rds.force_ssl"
      value        = "1"
      apply_method = "pending-reboot"
    },
  ]

  create_db_option_group = false

  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Sun:04:00-Sun:05:00"
  copy_tags_to_snapshot   = true

  enabled_cloudwatch_logs_exports        = ["postgresql", "upgrade"]
  create_cloudwatch_log_group            = true
  cloudwatch_log_group_retention_in_days = var.backup_retention_days

  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  apply_immediately           = var.apply_immediately

  deletion_protection      = var.deletion_protection
  skip_final_snapshot      = var.skip_final_snapshot
  delete_automated_backups = var.skip_final_snapshot

  performance_insights_enabled = false
  monitoring_interval          = 0

  tags = local.standard_tags
}
