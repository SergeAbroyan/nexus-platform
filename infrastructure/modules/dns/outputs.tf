output "zone_id" {
  description = "Route 53 hosted-zone ID."
  value       = module.zone.id
}

output "zone_arn" {
  description = "Route 53 hosted-zone ARN used by ExternalDNS IAM policy."
  value       = module.zone.arn
}

output "name_servers" {
  description = "Name servers that must be configured at the domain registrar."
  value       = module.zone.name_servers
}
