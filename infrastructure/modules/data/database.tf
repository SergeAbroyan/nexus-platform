locals {
  database_identifier  = "${var.name}-postgres"
  major_engine_version = split(".", var.database.engine_version)[0]
  standby_database     = var.replication_source != null
  replicating          = local.standby_database && !var.promote_replica
}

module "database_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "6.0.0"

  name            = local.database_identifier
  use_name_prefix = false
  description     = "PostgreSQL access from Nexus EKS nodes"
  vpc_id          = var.vpc_id

  ingress_rules = {
    postgresql_from_eks = {
      description                  = "PostgreSQL from EKS nodes"
      from_port                    = 5432
      to_port                      = 5432
      ip_protocol                  = "tcp"
      referenced_security_group_id = var.client_security_group_id
    }
  }

  egress_rules = {}

  tags = merge(var.tags, { Name = local.database_identifier })
}

module "database" {
  source  = "terraform-aws-modules/rds/aws"
  version = "7.2.0"

  identifier = local.database_identifier

  engine               = "postgres"
  engine_version       = var.database.engine_version
  major_engine_version = local.major_engine_version
  family               = "postgres${local.major_engine_version}"
  instance_class       = var.database.instance_class

  replicate_source_db = local.replicating ? var.replication_source.db_instance_arn : null
  db_name             = local.standby_database ? null : var.database.name
  username            = var.database.master_username
  port                = 5432

  manage_master_user_password   = !local.replicating
  master_user_secret_kms_key_id = var.kms_key_arns["rds"]

  allocated_storage     = var.database.allocated_storage
  max_allocated_storage = var.database.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arns["rds"]

  multi_az               = var.database.multi_az
  publicly_accessible    = false
  vpc_security_group_ids = [module.database_security_group.id]

  create_db_subnet_group          = true
  db_subnet_group_name            = local.database_identifier
  db_subnet_group_use_name_prefix = false
  subnet_ids                      = var.data_subnet_ids

  create_db_parameter_group       = true
  parameter_group_name            = local.database_identifier
  parameter_group_use_name_prefix = false
  parameters = [
    {
      name         = "rds.force_ssl"
      value        = "1"
      apply_method = "pending-reboot"
    },
  ]

  create_db_option_group = false

  backup_retention_period = var.database.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Sun:04:00-Sun:05:00"
  copy_tags_to_snapshot   = true

  enabled_cloudwatch_logs_exports        = ["postgresql", "upgrade"]
  create_cloudwatch_log_group            = true
  cloudwatch_log_group_retention_in_days = var.database.backup_retention_days

  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  apply_immediately           = var.database.apply_immediately

  deletion_protection      = var.database.deletion_protection
  skip_final_snapshot      = var.database.skip_final_snapshot
  delete_automated_backups = var.database.skip_final_snapshot

  performance_insights_enabled = false
  monitoring_interval          = 0

  tags = var.tags
}
