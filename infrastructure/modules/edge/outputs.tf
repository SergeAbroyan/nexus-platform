output "application_url" {
  description = "Public HTTPS application URL."
  value       = "https://${var.hostname}"
}

output "active_region" {
  description = "Region that currently receives traffic."
  value       = var.active_region
}

output "distribution_id" {
  description = "CloudFront distribution ID."
  value       = module.cloudfront.cloudfront_distribution_id
}
