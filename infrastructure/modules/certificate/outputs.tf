output "certificate_arn" {
  description = "Validated ACM certificate ARN for the Nexus hostname."
  value       = module.certificate.acm_certificate_arn
}
