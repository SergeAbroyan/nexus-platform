output "kms_key_arns" {
  description = "KMS key ARNs by logical key name."
  value       = { for name, key in module.kms : name => key.key_arn }
}

output "grafana_admin_secret_arn" {
  description = "ARN of the Grafana administrator password secret."
  value       = module.grafana_admin.secret_arn
}

output "alert_topic_arn" {
  description = "ARN of the regional SNS topic that receives alarms and alerts."
  value       = module.alerts.topic_arn
}
