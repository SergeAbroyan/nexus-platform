output "key_arns" {
  description = "Map of logical key names to KMS key ARNs."
  value       = { for name, key in module.kms : name => key.key_arn }
}

output "key_ids" {
  description = "Map of logical key names to KMS key IDs."
  value       = { for name, key in module.kms : name => key.key_id }
}
