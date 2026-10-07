output "controller_iam_role_arn" {
  description = "IAM role ARN used by the Karpenter controller through EKS Pod Identity."
  value       = module.karpenter.iam_role_arn
}

output "node_iam_role_name" {
  description = "IAM role name referenced by the Karpenter EC2NodeClass."
  value       = module.karpenter.node_iam_role_name
}

output "node_iam_role_arn" {
  description = "IAM role ARN assumed by EC2 instances created by Karpenter."
  value       = module.karpenter.node_iam_role_arn
}

output "interruption_queue_name" {
  description = "SQS queue name passed to the Karpenter Helm chart."
  value       = module.karpenter.queue_name
}

output "namespace" {
  description = "Kubernetes namespace associated with the Karpenter Pod Identity."
  value       = module.karpenter.namespace
}

output "service_account" {
  description = "Kubernetes service account associated with the Karpenter Pod Identity."
  value       = module.karpenter.service_account
}
