output "zone_id" {
  description = "Route 53 hosted-zone ID."
  value       = module.zone.id
}

output "name_servers" {
  description = "Name servers to configure at the domain registrar."
  value       = module.zone.name_servers
}

output "application_ci_role_arn" {
  description = "IAM role ARN for the applications repository CI; set it as AWS_ROLE_ARN in GitHub."
  value       = module.application_ci.arn
}

output "infrastructure_ci_role_arn" {
  description = "IAM role ARN for the infrastructure deployment workflow; set it as AWS_INFRASTRUCTURE_ROLE_ARN in GitHub."
  value       = module.infrastructure_ci.arn
}

output "repository_urls" {
  description = "Primary-region ECR repository URLs by service."
  value       = { for name, repository in module.repository : name => repository.repository_url }
}

output "standby_repository_urls" {
  description = "Standby-region ECR repository URLs that receive replicated images."
  value       = { for name, repository in module.standby_repository : name => repository.repository_url }
}
