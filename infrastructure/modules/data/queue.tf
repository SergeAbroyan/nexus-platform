module "queue" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "5.2.2"

  name     = "${var.name}-jobs"
  dlq_name = "${var.name}-jobs-dlq"

  create_dlq                      = true
  create_dlq_redrive_allow_policy = true
  redrive_policy = {
    maxReceiveCount = var.queue.max_receive_count
  }

  visibility_timeout_seconds    = var.queue.visibility_timeout_seconds
  message_retention_seconds     = var.queue.message_retention_seconds
  receive_wait_time_seconds     = var.queue.receive_wait_time_seconds
  dlq_message_retention_seconds = var.queue.dlq_message_retention_seconds

  kms_master_key_id                     = var.kms_key_arns["sqs"]
  dlq_kms_master_key_id                 = var.kms_key_arns["sqs"]
  kms_data_key_reuse_period_seconds     = var.queue.kms_data_key_reuse_period_seconds
  dlq_kms_data_key_reuse_period_seconds = var.queue.kms_data_key_reuse_period_seconds

  tags = var.tags
}
