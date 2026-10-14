locals {
  name = "${var.project_name}-${var.environment}"

  common_actions = [var.notification_topic_arn]
}

module "rds_cpu" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "5.7.2"

  alarm_name          = "${local.name}-rds-high-cpu"
  alarm_description   = "RDS CPU utilization is above the configured threshold."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  threshold           = var.rds_cpu_threshold_percent
  period              = var.period_seconds
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  unit                = "Percent"
  dimensions          = { DBInstanceIdentifier = var.rds_identifier }
  treat_missing_data  = "missing"
  alarm_actions       = local.common_actions
  ok_actions          = local.common_actions
}

module "rds_free_storage" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "5.7.2"

  alarm_name          = "${local.name}-rds-low-free-storage"
  alarm_description   = "RDS free storage is below the configured threshold."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.evaluation_periods
  threshold           = var.rds_free_storage_threshold_bytes
  period              = var.period_seconds
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Minimum"
  unit                = "Bytes"
  dimensions          = { DBInstanceIdentifier = var.rds_identifier }
  treat_missing_data  = "missing"
  alarm_actions       = local.common_actions
  ok_actions          = local.common_actions
}

module "valkey_memory" {
  for_each = toset(var.valkey_member_cluster_ids)

  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "5.7.2"

  alarm_name          = "${local.name}-${each.value}-high-memory"
  alarm_description   = "Valkey database memory usage is above the configured threshold."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  threshold           = var.valkey_memory_threshold_percent
  period              = var.period_seconds
  namespace           = "AWS/ElastiCache"
  metric_name         = "DatabaseMemoryUsagePercentage"
  statistic           = "Average"
  unit                = "Percent"
  dimensions          = { CacheClusterId = each.value }
  treat_missing_data  = "missing"
  alarm_actions       = local.common_actions
  ok_actions          = local.common_actions
}

module "sqs_oldest_message" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "5.7.2"

  alarm_name          = "${local.name}-sqs-oldest-message"
  alarm_description   = "The oldest unprocessed Nexus job is above the configured age."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.evaluation_periods
  threshold           = var.sqs_oldest_message_threshold_seconds
  period              = var.period_seconds
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  statistic           = "Maximum"
  unit                = "Seconds"
  dimensions          = { QueueName = var.sqs_queue_name }
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.common_actions
  ok_actions          = local.common_actions
}

module "sqs_dead_letter_messages" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "5.7.2"

  alarm_name          = "${local.name}-sqs-dead-letter-messages"
  alarm_description   = "The Nexus dead-letter queue contains one or more failed jobs."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0
  period              = var.period_seconds
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  unit                = "Count"
  dimensions          = { QueueName = var.sqs_dead_letter_queue_name }
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.common_actions
  ok_actions          = local.common_actions
}
