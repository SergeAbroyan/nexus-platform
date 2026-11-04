data "aws_region" "current" {}

locals {
  account_regions   = toset([data.aws_region.current.region, var.standby_region])
  guardduty_regions = var.guardduty_enabled ? local.account_regions : toset([])
}

resource "aws_guardduty_detector" "this" {
  for_each = local.guardduty_regions

  region                       = each.key
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = var.tags
}

resource "aws_guardduty_detector_feature" "eks_audit_logs" {
  for_each = aws_guardduty_detector.this

  region      = each.key
  detector_id = each.value.id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "runtime_monitoring" {
  for_each = aws_guardduty_detector.this

  region      = each.key
  detector_id = each.value.id
  name        = "RUNTIME_MONITORING"
  status      = "ENABLED"

  additional_configuration {
    name   = "EKS_ADDON_MANAGEMENT"
    status = "ENABLED"
  }
}
