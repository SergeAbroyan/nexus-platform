output "repository_arns" {
  description = "Map of service names to ECR repository ARNs."
  value       = { for name, repository in module.repository : name => repository.repository_arn }
}

output "repository_names" {
  description = "Map of service names to complete ECR repository names."
  value       = { for name, repository in module.repository : name => repository.repository_name }
}

output "repository_urls" {
  description = "Map of service names to ECR repository URLs."
  value       = { for name, repository in module.repository : name => repository.repository_url }
}
