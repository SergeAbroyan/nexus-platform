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
