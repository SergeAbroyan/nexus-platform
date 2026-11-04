locals {
  security_hub_regions = var.security_hub_enabled ? local.account_regions : toset([])
}

data "aws_iam_policy_document" "config_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config" {
  count = var.security_hub_enabled ? 1 : 0

  name               = "${var.name}-config"
  description        = "Role that AWS Config uses to record resource configurations for Security Hub"
  assume_role_policy = data.aws_iam_policy_document.config_trust.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "config" {
  count = var.security_hub_enabled ? 1 : 0

  role       = aws_iam_role.config[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "account" {
  for_each = local.security_hub_regions

  region   = each.key
  name     = "${var.name}-config"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = each.key == data.aws_region.current.region
  }

  recording_mode {
    recording_frequency = "DAILY"
  }
}

resource "aws_config_delivery_channel" "account" {
  for_each = local.security_hub_regions

  region         = each.key
  name           = "${var.name}-config"
  s3_bucket_name = module.audit_logs.s3_bucket_id
  s3_key_prefix  = "config"

  depends_on = [aws_config_configuration_recorder.account]
}

resource "aws_config_configuration_recorder_status" "account" {
  for_each = local.security_hub_regions

  region     = each.key
  name       = aws_config_configuration_recorder.account[each.key].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.account]
}

resource "aws_securityhub_account" "account" {
  for_each = local.security_hub_regions

  region                   = each.key
  enable_default_standards = false
  auto_enable_controls     = true

  depends_on = [aws_config_configuration_recorder_status.account]
}

resource "aws_securityhub_standards_subscription" "foundational" {
  for_each = local.security_hub_regions

  region        = each.key
  standards_arn = "arn:${local.partition}:securityhub:${each.key}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.account]
}

resource "aws_securityhub_standards_subscription" "cis" {
  for_each = local.security_hub_regions

  region        = each.key
  standards_arn = "arn:${local.partition}:securityhub:${each.key}::standards/cis-aws-foundations-benchmark/v/3.0.0"

  depends_on = [aws_securityhub_account.account]
}
