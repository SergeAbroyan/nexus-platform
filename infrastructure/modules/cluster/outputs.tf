output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint of the Kubernetes API server."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the Kubernetes API."
  value       = module.eks.cluster_certificate_authority_data
}

output "node_security_group_id" {
  description = "Security group shared by managed and Karpenter nodes."
  value       = module.eks.node_security_group_id
}

output "karpenter_node_iam_role_name" {
  description = "IAM role referenced by the Karpenter EC2NodeClass."
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_interruption_queue_name" {
  description = "SQS queue name passed to the Karpenter Helm chart."
  value       = module.karpenter.queue_name
}

output "karpenter_service_account" {
  description = "Namespace and name of the service account bound to the Karpenter controller role."
  value = {
    namespace = module.karpenter.namespace
    name      = module.karpenter.service_account
  }
}

output "fault_injection_experiment_template_ids" {
  description = "AWS FIS experiment template IDs by experiment; start one with aws fis start-experiment."
  value = {
    spot_interruption       = aws_fis_experiment_template.spot_interruption.id
    system_node_failure     = aws_fis_experiment_template.system_node_failure.id
    zone_network_disruption = aws_fis_experiment_template.zone_network_disruption.id
  }
}
