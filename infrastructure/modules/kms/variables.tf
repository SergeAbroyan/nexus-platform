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
