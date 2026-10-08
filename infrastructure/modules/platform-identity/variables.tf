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

variable "external_secrets_namespace" {
  description = "Kubernetes namespace containing the External Secrets controller."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.external_secrets_namespace)) && length(var.external_secrets_namespace) <= 63
    error_message = "The External Secrets namespace must be a valid Kubernetes DNS label no longer than 63 characters."
  }
}

variable "external_secrets_service_account" {
  description = "Kubernetes service account used by the External Secrets controller."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.external_secrets_service_account)) && length(var.external_secrets_service_account) <= 63
    error_message = "The External Secrets service account must be a valid Kubernetes DNS label no longer than 63 characters."
  }
}

variable "rds_master_user_secret_arn" {
  description = "ARN of the RDS-managed database credential secret."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:secretsmanager:[^:]+:[0-9]{12}:secret:.+$", var.rds_master_user_secret_arn))
    error_message = "The database credential secret must be a valid Secrets Manager ARN."
  }
}

variable "rds_kms_key_arn" {
  description = "ARN of the KMS key encrypting the RDS-managed database credential secret."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$", var.rds_kms_key_arn))
    error_message = "The database encryption key must be a valid KMS key ARN."
  }
}

variable "additional_secret_arns" {
  description = "Additional Secrets Manager ARNs readable by External Secrets."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for arn in var.additional_secret_arns :
      can(regex("^arn:[^:]+:secretsmanager:[^:]+:[0-9]{12}:secret:.+$", arn))
    ])
    error_message = "Every additional secret must be a valid Secrets Manager ARN."
  }
}

variable "additional_secret_kms_key_arns" {
  description = "KMS key ARNs required to decrypt additional platform secrets."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition = alltrue([
      for arn in var.additional_secret_kms_key_arns :
      can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$", arn))
    ])
    error_message = "Every additional secret KMS key must be a valid KMS key ARN."
  }
}

variable "tags" {
  description = "Additional tags merged with the module's standard tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
