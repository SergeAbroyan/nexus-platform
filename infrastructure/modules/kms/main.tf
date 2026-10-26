module "kms" {
  for_each = var.key_names

  source  = "terraform-aws-modules/kms/aws"
  version = "4.2.2"

  description             = "${var.project_name} ${var.environment} ${each.key} encryption key"
  key_usage               = "ENCRYPT_DECRYPT"
  key_spec                = "SYMMETRIC_DEFAULT"
  enable_default_policy   = true
  enable_key_rotation     = true
  multi_region            = false
  deletion_window_in_days = var.deletion_window_in_days

  key_statements = contains(keys(var.key_service_principals), each.key) ? [
    {
      sid       = "AllowAWSServicePrincipals"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
      resources = ["*"]
      principals = [{
        type        = "Service"
        identifiers = var.key_service_principals[each.key]
      }]
    },
  ] : null

  computed_aliases = {
    this = {
      name = "${var.project_name}/${var.environment}/${each.key}"
    }
  }

  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Name        = "${var.project_name}-${var.environment}-${each.key}"
    Project     = var.project_name
  })
}
