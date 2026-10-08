variable "project_name" {
  description = "Project name used in secret names and tags."
  type        = string
  nullable    = false
}

variable "environment" {
  description = "Deployment environment used in secret names and tags."
  type        = string
  nullable    = false
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt platform secrets."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$", var.kms_key_arn))
    error_message = "The platform secrets KMS key must be a valid KMS key ARN."
  }
}

variable "recovery_window_in_days" {
  description = "Days AWS retains a deleted secret before permanent removal."
  type        = number
  default     = 7
  nullable    = false

  validation {
    condition     = var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30
    error_message = "The recovery window must be between 7 and 30 days."
  }
}

variable "tags" {
  description = "Additional tags merged with the module's standard tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
