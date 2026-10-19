output "release_name" {
  description = "Name of the Terraform-managed Argo CD Helm release."
  value       = "argocd"
}

output "namespace" {
  description = "Kubernetes namespace containing Argo CD."
  value       = var.namespace
}

output "chart_version" {
  description = "Installed Argo CD Helm chart version."
  value       = var.chart_version
}
