variable "project_name" {
  description = "Project name used in Karpenter resource names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "The project name must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment used in Karpenter resource names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.environment))
    error_message = "The environment must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "cluster_name" {
  description = "Name of the EKS cluster managed by Karpenter."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.cluster_name) > 0
    error_message = "The EKS cluster name cannot be empty."
  }
}

variable "namespace" {
  description = "Kubernetes namespace containing the Karpenter service account."
  type        = string
  default     = "kube-system"
  nullable    = false
}

variable "service_account" {
  description = "Kubernetes service account associated with the Karpenter controller IAM role."
  type        = string
  default     = "karpenter"
  nullable    = false
}

variable "enable_spot_interruption" {
  description = "Whether to create the interruption queue and EventBridge rules used by Karpenter."
  type        = bool
  default     = true
  nullable    = false
}

variable "tags" {
  description = "Additional tags merged with the module's standard tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
