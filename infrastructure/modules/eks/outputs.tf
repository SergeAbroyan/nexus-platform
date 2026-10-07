output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint of the Kubernetes API server."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the Kubernetes API."
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_version" {
  description = "Kubernetes version running on the EKS cluster."
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = "ID of the additional EKS control-plane security group."
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "ID of the shared EKS node security group."
  value       = module.eks.node_security_group_id
}

output "ebs_csi_iam_role_arn" {
  description = "IAM role ARN assumed by the EBS CSI controller through EKS Pod Identity."
  value       = module.ebs_csi_pod_identity.iam_role_arn
}
