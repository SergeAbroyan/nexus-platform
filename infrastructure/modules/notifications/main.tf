locals {
  name = "${var.project_name}-${var.environment}-alerts"

  standard_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  })
}

module "alerts" {
  source  = "terraform-aws-modules/sns/aws"
  version = "7.1.1"

  name              = local.name
  display_name      = "${var.project_name} ${var.environment} alerts"
  kms_master_key_id = var.kms_key_arn
  signature_version = 2

  subscriptions = {
    email = {
      protocol = "email"
      endpoint = var.alert_email_address
    }
  }

  tags = merge(local.standard_tags, {
    Name = local.name
  })
}
