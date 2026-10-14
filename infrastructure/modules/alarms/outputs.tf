output "alarm_arns" {
  description = "ARNs of all infrastructure CloudWatch alarms."
  value = concat(
    [
      module.rds_cpu.cloudwatch_metric_alarm_arn,
      module.rds_free_storage.cloudwatch_metric_alarm_arn,
      module.sqs_oldest_message.cloudwatch_metric_alarm_arn,
      module.sqs_dead_letter_messages.cloudwatch_metric_alarm_arn,
    ],
    [for alarm in module.valkey_memory : alarm.cloudwatch_metric_alarm_arn],
  )
}
