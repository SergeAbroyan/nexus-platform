output "api_iam_role_arn" {
  description = "IAM role ARN assumed by the API service account."
  value       = module.api.iam_role_arn
}

output "api_iam_role_name" {
  description = "IAM role name associated with the API service account."
  value       = module.api.iam_role_name
}

output "worker_iam_role_arn" {
  description = "IAM role ARN assumed by the worker service account."
  value       = module.worker.iam_role_arn
}

output "worker_iam_role_name" {
  description = "IAM role name associated with the worker service account."
  value       = module.worker.iam_role_name
}

output "namespace" {
  description = "Kubernetes namespace containing the associated service accounts."
  value       = var.namespace
}

output "service_accounts" {
  description = "Kubernetes service-account names associated with workload IAM roles."
  value = {
    api    = var.api_service_account
    worker = var.worker_service_account
  }
}
