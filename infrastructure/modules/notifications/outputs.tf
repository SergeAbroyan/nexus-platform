output "topic_arn" {
  description = "ARN of the SNS topic used for platform alerts."
  value       = module.alerts.topic_arn
}

output "topic_name" {
  description = "Name of the SNS topic used for platform alerts."
  value       = module.alerts.topic_name
}
