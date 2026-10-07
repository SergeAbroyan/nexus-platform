output "release_name" {
  description = "Name of the Terraform-managed Argo CD Helm release."
  value       = helm_release.argocd.name
}

output "namespace" {
  description = "Kubernetes namespace containing Argo CD."
  value       = helm_release.argocd.namespace
}

output "chart_version" {
  description = "Installed Argo CD Helm chart version."
  value       = helm_release.argocd.version
}
