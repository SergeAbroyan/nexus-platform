variable "project_name" {
  description = "Project name used in tags."
  type        = string
  nullable    = false
}

variable "environment" {
  description = "Deployment environment used in tags."
  type        = string
  nullable    = false
}

variable "application_hostname" {
  description = "Fully qualified Nexus hostname covered by the ACM certificate."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", var.application_hostname))
    error_message = "The application hostname must be a valid lowercase DNS name."
  }
}

variable "zone_id" {
  description = "Route 53 hosted-zone ID used for DNS validation records."
  type        = string
  nullable    = false
}

variable "tags" {
  description = "Additional tags merged with standard tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
