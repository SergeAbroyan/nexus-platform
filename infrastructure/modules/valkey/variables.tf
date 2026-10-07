variable "project_name" {
  description = "Project name used in cache resource names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "The project name must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment used in cache resource names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.environment))
    error_message = "The environment must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "vpc_id" {
  description = "ID of the VPC containing the cache."
  type        = string
  nullable    = false
}

variable "data_subnet_ids" {
  description = "Private data subnet IDs used by the ElastiCache subnet group."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.data_subnet_ids) >= 2
    error_message = "ElastiCache requires data subnets in at least two Availability Zones."
  }
}

variable "eks_node_security_group_id" {
  description = "EKS node security group allowed to connect to Valkey."
  type        = string
  nullable    = false
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt the cache at rest."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$", var.kms_key_arn))
    error_message = "The cache encryption key must be a valid KMS key ARN."
  }
}

variable "engine_version" {
  description = "Valkey engine version."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.engine_version))
    error_message = "The Valkey engine version must use major.minor format."
  }
}

variable "node_type" {
  description = "ElastiCache node type."
  type        = string
  nullable    = false
}

variable "num_cache_clusters" {
  description = "Total number of cache nodes, including the primary and replicas."
  type        = number
  default     = 1
  nullable    = false

  validation {
    condition     = var.num_cache_clusters >= 1
    error_message = "At least one cache node is required."
  }
}

variable "multi_az" {
  description = "Whether replicas are distributed across Availability Zones with automatic failover."
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = !var.multi_az || var.num_cache_clusters >= 2
    error_message = "Multi-AZ requires at least two cache nodes."
  }
}

variable "snapshot_retention_days" {
  description = "Number of days ElastiCache retains automatic snapshots."
  type        = number
  default     = 7
  nullable    = false

  validation {
    condition     = var.snapshot_retention_days >= 0 && var.snapshot_retention_days <= 35
    error_message = "Snapshot retention must be between 0 and 35 days."
  }
}

variable "log_retention_days" {
  description = "Number of days CloudWatch retains Valkey engine and slow logs."
  type        = number
  default     = 30
  nullable    = false

  validation {
    condition     = var.log_retention_days >= 1
    error_message = "Valkey logs must be retained for at least one day."
  }
}

variable "apply_immediately" {
  description = "Whether eligible cache changes are applied immediately instead of during maintenance."
  type        = bool
  default     = false
  nullable    = false
}

variable "tags" {
  description = "Additional tags merged with the module's standard tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
