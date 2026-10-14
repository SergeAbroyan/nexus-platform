variable "project_name" {
  description = "Project name used in alarm names."
  type        = string
  nullable    = false
}

variable "environment" {
  description = "Deployment environment monitored by the alarms."
  type        = string
  nullable    = false
}

variable "notification_topic_arn" {
  description = "SNS topic ARN used for alarm and recovery notifications."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:sns:[^:]+:[0-9]{12}:.+$", var.notification_topic_arn))
    error_message = "The notification topic must be a valid SNS topic ARN."
  }
}

variable "rds_identifier" {
  description = "RDS instance identifier used by CloudWatch."
  type        = string
  nullable    = false
}

variable "valkey_member_cluster_ids" {
  description = "ElastiCache member cluster identifiers monitored independently."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.valkey_member_cluster_ids) > 0
    error_message = "At least one Valkey member cluster identifier is required."
  }
}

variable "sqs_queue_name" {
  description = "Primary SQS queue name."
  type        = string
  nullable    = false
}

variable "sqs_dead_letter_queue_name" {
  description = "Dead-letter SQS queue name."
  type        = string
  nullable    = false
}

variable "period_seconds" {
  description = "CloudWatch metric aggregation period in seconds."
  type        = number
  default     = 60
  nullable    = false

  validation {
    condition     = var.period_seconds >= 60
    error_message = "The CloudWatch period must be at least 60 seconds."
  }
}

variable "evaluation_periods" {
  description = "Consecutive periods required before a sustained alarm fires."
  type        = number
  default     = 5
  nullable    = false

  validation {
    condition     = var.evaluation_periods >= 1
    error_message = "At least one evaluation period is required."
  }
}

variable "rds_cpu_threshold_percent" {
  description = "RDS average CPU percentage that triggers an alarm."
  type        = number
  default     = 80
  nullable    = false

  validation {
    condition     = var.rds_cpu_threshold_percent > 0 && var.rds_cpu_threshold_percent <= 100
    error_message = "The RDS CPU threshold must be between 0 and 100 percent."
  }
}

variable "rds_free_storage_threshold_bytes" {
  description = "RDS free-storage byte count below which an alarm fires."
  type        = number
  default     = 5368709120
  nullable    = false

  validation {
    condition     = var.rds_free_storage_threshold_bytes > 0
    error_message = "The RDS free-storage threshold must be greater than zero."
  }
}

variable "valkey_memory_threshold_percent" {
  description = "Valkey database-memory percentage that triggers an alarm."
  type        = number
  default     = 80
  nullable    = false

  validation {
    condition     = var.valkey_memory_threshold_percent > 0 && var.valkey_memory_threshold_percent <= 100
    error_message = "The Valkey memory threshold must be between 0 and 100 percent."
  }
}

variable "sqs_oldest_message_threshold_seconds" {
  description = "Maximum acceptable age of the oldest unprocessed SQS message."
  type        = number
  default     = 300
  nullable    = false

  validation {
    condition     = var.sqs_oldest_message_threshold_seconds > 0
    error_message = "The oldest-message threshold must be greater than zero."
  }
}
