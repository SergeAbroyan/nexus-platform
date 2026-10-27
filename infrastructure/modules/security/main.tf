module "kms" {
  for_each = var.kms.key_names

  source  = "terraform-aws-modules/kms/aws"
  version = "4.2.2"

  description             = "${var.name} ${each.key} encryption key"
  key_usage               = "ENCRYPT_DECRYPT"
  key_spec                = "SYMMETRIC_DEFAULT"
  enable_default_policy   = true
  enable_key_rotation     = true
  multi_region            = false
  deletion_window_in_days = var.kms.deletion_window_in_days

  key_statements = contains(keys(var.kms.service_principals), each.key) ? [
    {
      sid       = "AllowAWSServicePrincipals"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
      resources = ["*"]
      principals = [{
        type        = "Service"
        identifiers = var.kms.service_principals[each.key]
      }]
    },
  ] : null

  computed_aliases = {
    this = {
      name = "${var.name}/${each.key}"
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })
}

module "grafana_admin" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "2.2.0"

  name                    = "${var.name}/grafana/admin-password"
  description             = "Grafana administrator password for ${var.name}"
  kms_key_id              = module.kms["secrets"].key_arn
  recovery_window_in_days = var.secret_recovery_window_in_days

  create_random_password           = true
  random_password_length           = 32
  random_password_override_special = "!@#%^*-_=+"

  tags = merge(var.tags, { Name = "${var.name}-grafana-admin-password" })
}

module "alerts" {
  source  = "terraform-aws-modules/sns/aws"
  version = "7.2.0"

  name              = "${var.name}-alerts"
  display_name      = "${var.name} alerts"
  kms_master_key_id = module.kms["sns"].key_arn
  signature_version = 2

  subscriptions = {
    email = {
      protocol = "email"
      endpoint = var.alert_email_address
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-alerts" })
}
