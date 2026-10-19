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

variable "zone_name" {
  description = "Public Route 53 hosted-zone domain."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", var.zone_name))
    error_message = "The hosted-zone name must be a valid lowercase DNS name."
  }
}

variable "force_destroy" {
  description = "Whether Terraform may delete the hosted zone when records remain."
  type        = bool
  default     = false
  nullable    = false
}

variable "tags" {
  description = "Additional tags merged with standard tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
