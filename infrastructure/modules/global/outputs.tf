output "zone_id" {
  description = "Route 53 hosted-zone ID, or null when Cloudflare serves the domain and the Route 53 zone has been removed."
  value       = try(module.zone[0].id, null)
}

output "name_servers" {
  description = "Name servers to configure at the domain registrar: Cloudflare's once it serves the zone, otherwise Route 53's."
  value       = local.cloudflare_serves ? cloudflare_zone.this[0].name_servers : module.zone[0].name_servers
}

output "cloudflare_zone_id" {
  description = "Cloudflare zone ID of the public domain, or null when Cloudflare is not configured."
  value       = try(cloudflare_zone.this[0].id, null)
}

output "cloudflare_name_servers" {
  description = "Name servers Cloudflare assigned to the zone, or null when Cloudflare is not configured."
  value       = try(cloudflare_zone.this[0].name_servers, null)
}

output "admin_access" {
  description = "By environment: the Cloudflare Tunnel ID, the Secrets Manager secret, replicated to the standby region, that holds its token, and the address of each admin tool."
  value = {
    for environment in local.admin_environments : environment => {
      tunnel_id                = cloudflare_zero_trust_tunnel_cloudflared.admin[environment].id
      tunnel_token_secret_name = module.admin_tunnel_token[environment].secret_name
      hostnames                = { for tool in values(local.admin_tools) : tool.tool => tool.hostname if tool.environment == environment }
    }
  }
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

output "audit_bucket_name" {
  description = "S3 bucket that holds the CloudTrail logs and, with Security Hub enabled, the AWS Config history."
  value       = module.audit_logs.s3_bucket_id
}
