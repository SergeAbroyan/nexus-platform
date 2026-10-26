variable "project_name" {
  description = "Project name used in KMS aliases and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "The project name must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment used in KMS aliases and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.environment))
    error_message = "The environment must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "key_names" {
  description = "Names of the KMS keys to create for this environment."
  type        = set(string)
  nullable    = false

  validation {
    condition = (
      length(var.key_names) > 0 &&
      alltrue([for name in var.key_names : can(regex("^[a-z][a-z0-9-]*$", name))])
    )
    error_message = "Provide at least one key name using lowercase letters, numbers, or hyphens."
  }
}

variable "key_service_principals" {
  description = "AWS service principals, by key name, that may encrypt and decrypt with a key without an IAM role, such as CloudWatch publishing to an encrypted SNS topic."
  type        = map(list(string))
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for key_name, principals in var.key_service_principals :
      contains(var.key_names, key_name) &&
      length(principals) > 0 &&
      alltrue([for principal in principals : can(regex("^[a-z0-9.-]+\\.amazonaws\\.com$", principal))])
    ])
    error_message = "Each entry must name a key in key_names and list AWS service principals such as cloudwatch.amazonaws.com."
  }
}

variable "deletion_window_in_days" {
  description = "Number of days AWS waits before permanently deleting a scheduled KMS key."
  type        = number
  default     = 30
  nullable    = false

  validation {
    condition     = var.deletion_window_in_days >= 7 && var.deletion_window_in_days <= 30
    error_message = "The KMS deletion window must be between 7 and 30 days."
  }
}

variable "tags" {
  description = "Additional tags merged with the module's standard tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
