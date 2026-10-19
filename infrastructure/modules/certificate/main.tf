locals {
  standard_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  })
}

module "certificate" {
  source  = "terraform-aws-modules/acm/aws"
  version = "6.3.1"

  domain_name         = var.application_hostname
  zone_id             = var.zone_id
  validation_method   = "DNS"
  wait_for_validation = true

  tags = merge(local.standard_tags, {
    Name = var.application_hostname
  })
}
