variable "project_name" {
  description = "Project name used in IAM role names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "The project name must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment used in IAM role names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.environment))
    error_message = "The environment must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "cluster_name" {
  description = "EKS cluster where the platform controller runs."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.cluster_name)) > 0
    error_message = "The EKS cluster name cannot be empty."
  }
}

variable "load_balancer_controller_namespace" {
  description = "Kubernetes namespace containing the AWS Load Balancer Controller."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.load_balancer_controller_namespace)) && length(var.load_balancer_controller_namespace) <= 63
    error_message = "The controller namespace must be a valid Kubernetes DNS label no longer than 63 characters."
  }
}

variable "load_balancer_controller_service_account" {
  description = "Kubernetes service account used by the AWS Load Balancer Controller."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.load_balancer_controller_service_account)) && length(var.load_balancer_controller_service_account) <= 63
    error_message = "The controller service account must be a valid Kubernetes DNS label no longer than 63 characters."
  }
}

variable "tags" {
  description = "Additional tags merged with the module's standard tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
