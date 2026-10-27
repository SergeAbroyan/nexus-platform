output "ingress_load_balancer_arn" {
  description = "ARN of the internal load balancer that CloudFront uses as a VPC origin."
  value       = module.ingress_load_balancer.arn
}

output "ingress_load_balancer_dns_name" {
  description = "DNS name of the internal ingress load balancer."
  value       = module.ingress_load_balancer.dns_name
}

output "argocd_namespace" {
  description = "Kubernetes namespace that contains Argo CD."
  value       = var.argocd.namespace
}
