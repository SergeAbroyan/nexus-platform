output "load_balancer_controller_iam_role_arn" {
  description = "IAM role ARN assumed by the AWS Load Balancer Controller."
  value       = module.load_balancer_controller.iam_role_arn
}

output "load_balancer_controller_iam_role_name" {
  description = "IAM role name associated with the AWS Load Balancer Controller."
  value       = module.load_balancer_controller.iam_role_name
}

output "load_balancer_controller_iam_policy_arn" {
  description = "IAM policy ARN granting AWS Load Balancer Controller permissions."
  value       = module.load_balancer_controller.iam_policy_arn
}

output "load_balancer_controller_namespace" {
  description = "Kubernetes namespace associated with the controller IAM role."
  value       = var.load_balancer_controller_namespace
}

output "load_balancer_controller_service_account" {
  description = "Kubernetes service account associated with the controller IAM role."
  value       = var.load_balancer_controller_service_account
}

output "external_secrets_iam_role_arn" {
  description = "IAM role ARN assumed by the External Secrets controller."
  value       = module.external_secrets.iam_role_arn
}

output "external_secrets_iam_role_name" {
  description = "IAM role name associated with the External Secrets controller."
  value       = module.external_secrets.iam_role_name
}

output "external_secrets_iam_policy_arn" {
  description = "IAM policy ARN granting read-only access to the database secret."
  value       = module.external_secrets.iam_policy_arn
}

output "external_secrets_namespace" {
  description = "Kubernetes namespace associated with the External Secrets IAM role."
  value       = var.external_secrets_namespace
}

output "external_secrets_service_account" {
  description = "Kubernetes service account associated with the External Secrets IAM role."
  value       = var.external_secrets_service_account
}

output "external_dns_iam_role_arn" {
  description = "IAM role assumed by ExternalDNS through EKS Pod Identity."
  value       = module.external_dns.iam_role_arn
}

output "alertmanager_iam_role_arn" {
  description = "IAM role assumed by Alertmanager through EKS Pod Identity."
  value       = module.alertmanager.iam_role_arn
}

output "grafana_iam_role_arn" {
  description = "IAM role assumed by Grafana through EKS Pod Identity."
  value       = module.grafana.iam_role_arn
}
