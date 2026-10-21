output "node_iam_role_name" {
  description = "IAM role name referenced by the Karpenter EC2NodeClass."
  value       = module.karpenter.node_iam_role_name
}

output "interruption_queue_name" {
  description = "SQS queue name passed to the Karpenter Helm chart."
  value       = module.karpenter.queue_name
}
