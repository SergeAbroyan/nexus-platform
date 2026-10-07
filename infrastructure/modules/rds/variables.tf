variable "project_name" {
  description = "Project name used in RDS resource names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "The project name must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment used in RDS resource names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.environment))
    error_message = "The environment must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "vpc_id" {
  description = "ID of the VPC containing the database."
  type        = string
  nullable    = false
}

variable "data_subnet_ids" {
  description = "Private data subnet IDs used by the RDS subnet group."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.data_subnet_ids) >= 2
    error_message = "RDS requires data subnets in at least two Availability Zones."
  }
}

variable "eks_node_security_group_id" {
  description = "EKS node security group allowed to connect to PostgreSQL."
  type        = string
  nullable    = false
}

variable "kms_key_arn" {
  description = "KMS key ARN used for database storage and the managed master-user secret."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$", var.kms_key_arn))
    error_message = "The RDS encryption key must be a valid KMS key ARN."
  }
}

variable "database_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]*$", var.database_name))
    error_message = "The database name must start with a letter and contain only letters, numbers, or underscores."
  }
}

variable "master_username" {
  description = "PostgreSQL administrator username whose password is managed by RDS."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]*$", var.master_username))
    error_message = "The master username must start with a letter and contain only letters, numbers, or underscores."
  }
}

variable "engine_version" {
  description = "PostgreSQL engine version or major-version prefix."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?$", var.engine_version))
    error_message = "The PostgreSQL engine version must be a major or major.minor number."
  }
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  nullable    = false
}

variable "allocated_storage" {
  description = "Initial GP3 storage allocation in GiB."
  type        = number
  nullable    = false

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "PostgreSQL requires at least 20 GiB of allocated storage."
  }
}

variable "max_allocated_storage" {
  description = "Maximum storage allocation in GiB when RDS storage autoscaling is used."
  type        = number
  nullable    = false

  validation {
    condition     = var.max_allocated_storage >= var.allocated_storage
    error_message = "Maximum storage must be greater than or equal to initial storage."
  }
}

variable "multi_az" {
  description = "Whether to maintain a synchronous standby database in another Availability Zone."
  type        = bool
  default     = false
  nullable    = false
}

variable "backup_retention_days" {
  description = "Number of days RDS retains automated backups."
  type        = number
  default     = 7
  nullable    = false

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "RDS backup retention must be between 1 and 35 days."
  }
}

variable "deletion_protection" {
  description = "Whether AWS prevents accidental deletion of the database."
  type        = bool
  default     = true
  nullable    = false
}

variable "skip_final_snapshot" {
  description = "Whether database deletion may proceed without creating a final snapshot."
  type        = bool
  default     = false
  nullable    = false
}

variable "apply_immediately" {
  description = "Whether eligible database changes are applied immediately instead of during maintenance."
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
