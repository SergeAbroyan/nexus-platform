variable "project_name" {
  description = "Project name used in queue names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "The project name must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment used in queue names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.environment))
    error_message = "The environment must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt the queue and dead-letter queue."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$", var.kms_key_arn))
    error_message = "The queue encryption key must be a valid KMS key ARN."
  }
}

variable "visibility_timeout_seconds" {
  description = "Time a received message remains hidden while a worker processes it."
  type        = number
  default     = 60
  nullable    = false

  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "The visibility timeout must be between 0 and 43200 seconds."
  }
}

variable "message_retention_seconds" {
  description = "Time an unprocessed message remains in the primary queue."
  type        = number
  default     = 345600
  nullable    = false

  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "Message retention must be between 60 and 1209600 seconds."
  }
}

variable "dlq_message_retention_seconds" {
  description = "Time a failed message remains in the dead-letter queue for investigation."
  type        = number
  default     = 1209600
  nullable    = false

  validation {
    condition     = var.dlq_message_retention_seconds >= 60 && var.dlq_message_retention_seconds <= 1209600
    error_message = "Dead-letter queue retention must be between 60 and 1209600 seconds."
  }
}

variable "receive_wait_time_seconds" {
  description = "Maximum long-poll duration for receiving messages."
  type        = number
  default     = 20
  nullable    = false

  validation {
    condition     = var.receive_wait_time_seconds >= 0 && var.receive_wait_time_seconds <= 20
    error_message = "The receive wait time must be between 0 and 20 seconds."
  }
}

variable "max_receive_count" {
  description = "Failed delivery attempts allowed before a message moves to the dead-letter queue."
  type        = number
  default     = 5
  nullable    = false

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000 && floor(var.max_receive_count) == var.max_receive_count
    error_message = "The maximum receive count must be a whole number between 1 and 1000."
  }
}

variable "kms_data_key_reuse_period_seconds" {
  description = "Time SQS reuses a KMS data key before requesting a new one."
  type        = number
  default     = 300
  nullable    = false

  validation {
    condition     = var.kms_data_key_reuse_period_seconds >= 60 && var.kms_data_key_reuse_period_seconds <= 86400
    error_message = "The KMS data-key reuse period must be between 60 and 86400 seconds."
  }
}

variable "tags" {
  description = "Additional tags merged with the module's standard tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
