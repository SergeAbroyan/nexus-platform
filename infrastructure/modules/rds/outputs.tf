output "address" {
  description = "Private DNS name of the PostgreSQL instance."
  value       = module.database.db_instance_address
}

output "endpoint" {
  description = "PostgreSQL connection endpoint including the port."
  value       = module.database.db_instance_endpoint
}

output "port" {
  description = "PostgreSQL listener port."
  value       = module.database.db_instance_port
}

output "database_name" {
  description = "Initial PostgreSQL database name."
  value       = module.database.db_instance_name
}

output "username" {
  description = "Database username stored with the RDS-managed password."
  value       = module.database.db_instance_username
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN containing the RDS-managed administrator credentials."
  value       = module.database.db_instance_master_user_secret_arn
}

output "security_group_id" {
  description = "Security group attached to the PostgreSQL instance."
  value       = module.security_group.id
}
