locals {
  name = "${var.project_name}-${var.environment}"

  standard_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  })
}

module "grafana_admin" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "2.0.0"

  name                    = "${local.name}/grafana/admin-password"
  description             = "Grafana administrator password for ${local.name}"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_in_days

  create_random_password           = true
  random_password_length           = 32
  random_password_override_special = "!@#%^*-_=+"

  tags = merge(local.standard_tags, {
    Name = "${local.name}-grafana-admin-password"
  })
}
