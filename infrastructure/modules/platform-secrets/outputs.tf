output "grafana_admin_secret_arn" {
  description = "ARN of the Grafana administrator password secret."
  value       = module.grafana_admin.secret_arn
}

output "grafana_admin_secret_name" {
  description = "Name of the Grafana administrator password secret."
  value       = module.grafana_admin.secret_name
}
