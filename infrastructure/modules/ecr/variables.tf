variable "project_name" {
  description = "Project namespace used as the repository-name prefix."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "The project name must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment used for tagging."
  type        = string
  nullable    = false
}

variable "repository_names" {
  description = "Service repository names created below the project namespace."
  type        = set(string)
  nullable    = false

  validation {
    condition = (
      length(var.repository_names) > 0 &&
      alltrue([for name in var.repository_names : can(regex("^[a-z][a-z0-9-]*$", name))])
    )
    error_message = "Provide at least one repository name using lowercase letters, numbers, or hyphens."
  }
}

variable "force_delete" {
  description = "Whether repositories may be destroyed while they still contain images."
  type        = bool
  default     = false
  nullable    = false
}

variable "untagged_image_retention_days" {
  description = "Number of days an untagged image is retained."
  type        = number
  default     = 7
  nullable    = false

  validation {
    condition     = var.untagged_image_retention_days >= 1
    error_message = "Untagged images must be retained for at least one day."
  }
}

variable "maximum_image_count" {
  description = "Maximum number of images retained in each repository."
  type        = number
  default     = 20
  nullable    = false

  validation {
    condition     = var.maximum_image_count >= 1
    error_message = "At least one image must be retained."
  }
}

variable "tags" {
  description = "Additional tags merged with the module's standard tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
