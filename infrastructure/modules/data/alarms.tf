module "rds_cpu_alarm" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "5.7.3"

  alarm_name          = "${var.name}-rds-high-cpu"
  alarm_description   = "RDS CPU utilization is above the configured threshold."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarms.evaluation_periods
  threshold           = var.alarms.rds_cpu_threshold_percent
  period              = var.alarms.period_seconds
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  unit                = "Percent"
  dimensions          = { DBInstanceIdentifier = module.database.db_instance_identifier }
  treat_missing_data  = "missing"
  alarm_actions       = [var.alert_topic_arn]
  ok_actions          = [var.alert_topic_arn]

  tags = var.tags
}

module "rds_free_storage_alarm" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "5.7.3"

  alarm_name          = "${var.name}-rds-low-free-storage"
  alarm_description   = "RDS free storage is below the configured threshold."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.alarms.evaluation_periods
  threshold           = var.alarms.rds_free_storage_threshold_bytes
  period              = var.alarms.period_seconds
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Minimum"
  unit                = "Bytes"
  dimensions          = { DBInstanceIdentifier = module.database.db_instance_identifier }
  treat_missing_data  = "missing"
  alarm_actions       = [var.alert_topic_arn]
  ok_actions          = [var.alert_topic_arn]

  tags = var.tags
}

module "valkey_memory_alarm" {
  for_each = toset([for index in range(var.cache.num_cache_clusters) : format("%s-%03d", local.cache_name, index + 1)])

  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "5.7.3"

  alarm_name          = "${var.name}-${each.value}-high-memory"
  alarm_description   = "Valkey database memory usage is above the configured threshold."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarms.evaluation_periods
  threshold           = var.alarms.valkey_memory_threshold_percent
  period              = var.alarms.period_seconds
  namespace           = "AWS/ElastiCache"
  metric_name         = "DatabaseMemoryUsagePercentage"
  statistic           = "Average"
  unit                = "Percent"
  dimensions          = { CacheClusterId = each.value }
  treat_missing_data  = "missing"
  alarm_actions       = [var.alert_topic_arn]
  ok_actions          = [var.alert_topic_arn]

  tags = var.tags
}

module "sqs_oldest_message_alarm" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "5.7.3"

  alarm_name          = "${var.name}-sqs-oldest-message"
  alarm_description   = "The oldest unprocessed Nexus job is above the configured age."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarms.evaluation_periods
  threshold           = var.alarms.sqs_oldest_message_threshold_seconds
  period              = var.alarms.period_seconds
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  statistic           = "Maximum"
  unit                = "Seconds"
  dimensions          = { QueueName = module.queue.queue_name }
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alert_topic_arn]
  ok_actions          = [var.alert_topic_arn]

  tags = var.tags
}

module "sqs_dead_letter_alarm" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "5.7.3"

  alarm_name          = "${var.name}-sqs-dead-letter-messages"
  alarm_description   = "The Nexus dead-letter queue contains one or more failed jobs."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0
  period              = var.alarms.period_seconds
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  unit                = "Count"
  dimensions          = { QueueName = module.queue.dead_letter_queue_name }
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alert_topic_arn]
  ok_actions          = [var.alert_topic_arn]

  tags = var.tags
}
