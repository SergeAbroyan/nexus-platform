locals {
  name = "${var.project_name}-${var.environment}-jobs"

  standard_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  })
}

module "queue" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "5.2.2"

  name     = local.name
  dlq_name = "${local.name}-dlq"

  create_dlq                      = true
  create_dlq_redrive_allow_policy = true
  redrive_policy = {
    maxReceiveCount = var.max_receive_count
  }

  visibility_timeout_seconds    = var.visibility_timeout_seconds
  message_retention_seconds     = var.message_retention_seconds
  receive_wait_time_seconds     = var.receive_wait_time_seconds
  dlq_message_retention_seconds = var.dlq_message_retention_seconds

  kms_master_key_id                     = var.kms_key_arn
  dlq_kms_master_key_id                 = var.kms_key_arn
  kms_data_key_reuse_period_seconds     = var.kms_data_key_reuse_period_seconds
  dlq_kms_data_key_reuse_period_seconds = var.kms_data_key_reuse_period_seconds

  tags = local.standard_tags
}
