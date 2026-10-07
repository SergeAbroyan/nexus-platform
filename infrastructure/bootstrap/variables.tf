variable "aws_region" {
  description = "AWS Region where the Terraform state bucket will be created."
  type        = string
  default     = "us-east-1"
  nullable    = false
}

variable "project_name" {
  description = "Project name used as a prefix for shared infrastructure."
  type        = string
  default     = "nexus"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "The project name must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}
