locals {
  standard_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  })
}

module "zone" {
  source  = "terraform-aws-modules/route53/aws"
  version = "6.5.1"

  name          = var.zone_name
  comment       = "Public DNS zone for ${var.project_name} ${var.environment}"
  force_destroy = var.force_destroy

  tags = merge(local.standard_tags, {
    Name = var.zone_name
  })
}

module "certificate" {
  source  = "terraform-aws-modules/acm/aws"
  version = "6.3.1"

  domain_name         = var.application_hostname
  zone_id             = module.zone.id
  validation_method   = "DNS"
  wait_for_validation = true

  tags = merge(local.standard_tags, {
    Name = var.application_hostname
  })
}
