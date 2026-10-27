variable "name" {
  description = "Regional resource name prefix, such as nexus-dev-use1."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.name))
    error_message = "The name must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "tags" {
  description = "Tags added to every resource."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "kms" {
  description = "KMS keys to create, AWS service principals allowed to use specific keys, and the key deletion window."
  type = object({
    key_names               = set(string)
    service_principals      = map(list(string))
    deletion_window_in_days = number
  })
  nullable = false

  validation {
    condition = (
      alltrue([for required in ["ebs", "eks", "rds", "secrets", "sns", "sqs", "valkey"] : contains(var.kms.key_names, required)]) &&
      alltrue([for key_name in var.kms.key_names : can(regex("^[a-z][a-z0-9-]*$", key_name))]) &&
      alltrue([
        for key_name, principals in var.kms.service_principals :
        contains(var.kms.key_names, key_name) &&
        length(principals) > 0 &&
        alltrue([for principal in principals : can(regex("^[a-z0-9.-]+\\.amazonaws\\.com$", principal))])
      ]) &&
      var.kms.deletion_window_in_days >= 7 &&
      var.kms.deletion_window_in_days <= 30
    )
    error_message = "Include the ebs, eks, rds, secrets, sns, sqs, and valkey keys, use lowercase key names, service principals such as cloudwatch.amazonaws.com for existing keys, and a deletion window of 7 to 30 days."
  }
}

variable "secret_recovery_window_in_days" {
  description = "Days AWS retains a deleted platform secret before permanent removal."
  type        = number
  nullable    = false

  validation {
    condition     = var.secret_recovery_window_in_days >= 7 && var.secret_recovery_window_in_days <= 30
    error_message = "The secret recovery window must be between 7 and 30 days."
  }
}

variable "alert_email_address" {
  description = "Email address subscribed to the regional alert topic."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email_address))
    error_message = "The alert address must be a valid email address."
  }
}
