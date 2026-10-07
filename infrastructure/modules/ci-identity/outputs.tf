output "github_oidc_provider_arn" {
  description = "ARN of the account-level GitHub Actions OIDC provider."
  value       = module.github_oidc_provider.arn
}

output "application_ci_iam_role_arn" {
  description = "IAM role ARN assumed by the applications repository on the deployment branch."
  value       = module.application_ci.arn
}

output "application_ci_iam_role_name" {
  description = "IAM role name used by application image-publishing workflows."
  value       = module.application_ci.name
}

output "infrastructure_ci_iam_role_arn" {
  description = "IAM role ARN assumed by the infrastructure repository on the deployment branch."
  value       = module.infrastructure_ci.arn
}

output "infrastructure_ci_iam_role_name" {
  description = "IAM role name used by infrastructure deployment workflows."
  value       = module.infrastructure_ci.name
}
