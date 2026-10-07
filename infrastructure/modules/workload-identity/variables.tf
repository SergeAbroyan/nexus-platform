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
  description = "EKS cluster where the Kubernetes service accounts run."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.cluster_name)) > 0
    error_message = "The EKS cluster name cannot be empty."
  }
}

variable "namespace" {
  description = "Kubernetes namespace containing the application service accounts."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace)) && length(var.namespace) <= 63
    error_message = "The namespace must be a valid Kubernetes DNS label no longer than 63 characters."
  }
}

variable "api_service_account" {
  description = "Kubernetes service account used by the API workload."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.api_service_account)) && length(var.api_service_account) <= 63
    error_message = "The API service account must be a valid Kubernetes DNS label no longer than 63 characters."
  }
}

variable "worker_service_account" {
  description = "Kubernetes service account used by the worker workload."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.worker_service_account)) && length(var.worker_service_account) <= 63
    error_message = "The worker service account must be a valid Kubernetes DNS label no longer than 63 characters."
  }
}

variable "sqs_queue_arn" {
  description = "ARN of the job queue used by the API and worker."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:sqs:[^:]+:[0-9]{12}:.+$", var.sqs_queue_arn))
    error_message = "The job queue must be a valid SQS queue ARN."
  }
}

variable "sqs_kms_key_arn" {
  description = "ARN of the KMS key encrypting the job queue."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$", var.sqs_kms_key_arn))
    error_message = "The queue encryption key must be a valid KMS key ARN."
  }
}

variable "valkey_replication_group_arn" {
  description = "ARN of the Valkey replication group used by the API."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:elasticache:[^:]+:[0-9]{12}:replicationgroup:.+$", var.valkey_replication_group_arn))
    error_message = "The Valkey replication group must be a valid ElastiCache ARN."
  }
}

variable "valkey_user_arn" {
  description = "ARN of the IAM-authenticated Valkey user used by the API."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:elasticache:[^:]+:[0-9]{12}:user:.+$", var.valkey_user_arn))
    error_message = "The Valkey user must be a valid ElastiCache user ARN."
  }
}

variable "tags" {
  description = "Additional tags merged with the module's standard tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
