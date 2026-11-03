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

output "infrastructure_ci_role_arns" {
  description = "Infrastructure deployment role ARN by environment; set each as AWS_INFRASTRUCTURE_ROLE_ARN in the GitHub environment of the same name."
  value       = { for environment, role in module.infrastructure_ci : environment => role.arn }
}

output "repository_urls" {
  description = "Primary-region ECR repository URLs by service."
  value       = { for name, repository in module.repository : name => repository.repository_url }
}

output "standby_repository_urls" {
  description = "Standby-region ECR repository URLs that receive replicated images."
  value       = { for name, repository in module.standby_repository : name => repository.repository_url }
}

output "gitops_deploy_key_secret_name" {
  description = "Secrets Manager secret, replicated to the standby region, that holds the read-only SSH key Argo CD uses for the GitOps repository."
  value       = module.gitops_deploy_key.secret_name
}

output "argocd_github_oauth_secret_name" {
  description = "Secrets Manager secret, replicated to the standby region, that holds the client secret of the GitHub OAuth app for Argo CD sign-in."
  value       = module.argocd_github_oauth.secret_name
}

output "slack_webhook_secret_name" {
  description = "Secrets Manager secret, replicated to the standby region, that holds the Slack webhook URL for Alertmanager."
  value       = module.slack_webhook.secret_name
}
