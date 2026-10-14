output "replication_group_arn" {
  description = "ARN of the Valkey replication group."
  value       = module.cache.replication_group_arn
}

output "replication_group_id" {
  description = "Replication group identifier used when generating IAM authentication tokens."
  value       = module.cache.replication_group_id
}

output "member_cluster_ids" {
  description = "ElastiCache member cluster identifiers used by CloudWatch dimensions."
  value       = module.cache.replication_group_member_clusters
}

output "primary_endpoint" {
  description = "Primary Valkey endpoint used for reads and writes."
  value       = module.cache.replication_group_primary_endpoint_address
}

output "reader_endpoint" {
  description = "Reader Valkey endpoint used to distribute read traffic across replicas."
  value       = module.cache.replication_group_reader_endpoint_address
}

output "port" {
  description = "TLS listener port for Valkey."
  value       = module.cache.replication_group_port
}

output "application_user_name" {
  description = "IAM-authenticated Valkey username used by the API service."
  value       = local.application_user_name
}

output "application_user_arn" {
  description = "ARN of the IAM-authenticated Valkey application user."
  value       = module.user_group.users[local.application_user_name].arn
}

output "security_group_id" {
  description = "Security group attached to the Valkey replication group."
  value       = module.cache.security_group_id
}
