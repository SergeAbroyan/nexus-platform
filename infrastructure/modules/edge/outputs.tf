output "enabled" {
  description = "Whether the CloudFront edge layer is enabled."
  value       = var.enable_cdn
}

output "distribution_id" {
  description = "CloudFront distribution ID, or null when the CDN is disabled."
  value       = try(module.cloudfront[0].cloudfront_distribution_id, null)
}

output "distribution_domain_name" {
  description = "CloudFront-generated domain name, or null when the CDN is disabled."
  value       = try(module.cloudfront[0].cloudfront_distribution_domain_name, null)
}

output "application_url" {
  description = "Public HTTPS application URL, or null when the CDN is disabled."
  value       = var.enable_cdn ? "https://${var.hostname}" : null
}

output "web_acl_arn" {
  description = "CloudFront WAF web ACL ARN, or null when WAF is disabled."
  value       = try(module.waf[0].web_acl_arn, null)
}
