variable "project_name" {
  description = "Project name used for the budget name and tags."
  type        = string
  nullable    = false
}

variable "environment" {
  description = "Deployment environment used for the budget name and tags."
  type        = string
  nullable    = false
}

variable "monthly_limit_usd" {
  description = "Monthly cost budget in US dollars."
  type        = number
  nullable    = false

  validation {
    condition     = var.monthly_limit_usd > 0
    error_message = "The monthly budget must be greater than zero."
  }
}

variable "notification_email" {
  description = "Email address that receives budget notifications."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.notification_email))
    error_message = "The budget notification address must be a valid email address."
  }
}

variable "tags" {
  description = "Additional tags merged with standard tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
