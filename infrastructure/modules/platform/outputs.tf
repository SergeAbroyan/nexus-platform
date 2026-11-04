output "ingress_load_balancer_arn" {
  description = "ARN of the internal load balancer that CloudFront uses as a VPC origin."
  value       = module.ingress_load_balancer.arn
}

output "ingress_load_balancer_dns_name" {
  description = "DNS name of the internal ingress load balancer."
  value       = module.ingress_load_balancer.dns_name
}

output "backup_bucket_name" {
  description = "S3 bucket that holds the Velero backups of this cluster."
  value       = module.backup_bucket.s3_bucket_id
}

output "argocd_namespace" {
  description = "Kubernetes namespace that contains Argo CD."
  value       = var.argocd.namespace
}
