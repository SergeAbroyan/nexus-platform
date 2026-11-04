output "database_arn" {
  description = "ARN of the PostgreSQL instance, used as the source of the standby replica."
  value       = module.database.db_instance_arn
}

output "database_address" {
  description = "Private DNS name of the PostgreSQL instance."
  value       = module.database.db_instance_address
}

output "database_port" {
  description = "PostgreSQL listener port."
  value       = module.database.db_instance_port
}

output "database_name" {
  description = "PostgreSQL database used by Nexus."
  value       = var.database.name
}

output "database_username" {
  description = "PostgreSQL user whose password is in the database secret."
  value       = var.database.master_username
}

output "database_secret_arn" {
  description = "Secrets Manager ARN with the database password; the primary region's secret while this region replicates."
  value       = local.replicating ? var.replication_source.master_user_secret_arn : module.database.db_instance_master_user_secret_arn
}

output "database_secret_kms_key_arn" {
  description = "KMS key that encrypts the database secret."
  value       = local.replicating ? var.replication_source.master_user_secret_kms_key_arn : var.kms_key_arns["rds"]
}

output "cache_primary_endpoint" {
  description = "Primary Valkey endpoint used for reads and writes."
  value       = module.cache.replication_group_primary_endpoint_address
}

output "cache_port" {
  description = "TLS listener port for Valkey."
  value       = module.cache.replication_group_port
}

output "cache_replication_group_id" {
  description = "Replication group identifier used when generating IAM authentication tokens."
  value       = module.cache.replication_group_id
}

output "cache_replication_group_arn" {
  description = "ARN of the Valkey replication group."
  value       = module.cache.replication_group_arn
}

output "cache_user_name" {
  description = "IAM-authenticated Valkey user for the API."
  value       = local.cache_user_name
}

output "cache_user_arn" {
  description = "ARN of the IAM-authenticated Valkey user."
  value       = module.cache_users.users[local.cache_user_name].arn
}

output "queue_url" {
  description = "URL of the job queue."
  value       = module.queue.queue_url
}

output "queue_arn" {
  description = "ARN of the job queue."
  value       = module.queue.queue_arn
}

output "backup_vault_name" {
  description = "AWS Backup vault that holds the database recovery points; null in a region that is still replicating."
  value       = one(aws_backup_vault.database[*].name)
}
