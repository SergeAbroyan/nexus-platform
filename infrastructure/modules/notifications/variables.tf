variable "project_name" {
  description = "Project name used in notification resource names."
  type        = string
  nullable    = false
}

variable "environment" {
  description = "Deployment environment receiving the alerts."
  type        = string
  nullable    = false
}

variable "alert_email_address" {
  description = "Email address subscribed to platform alerts."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", var.alert_email_address))
    error_message = "The alert email address must be a valid email address."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt the SNS topic."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$", var.kms_key_arn))
    error_message = "The notification encryption key must be a valid KMS key ARN."
  }
}

variable "tags" {
  description = "Additional tags merged with the module's standard tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
