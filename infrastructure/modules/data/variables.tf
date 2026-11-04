variable "name" {
  description = "Regional resource name prefix, such as nexus-dev-use1."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.name))
    error_message = "The name must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "tags" {
  description = "Tags added to every resource."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "vpc_id" {
  description = "ID of the VPC that contains the data services."
  type        = string
  nullable    = false
}

variable "data_subnet_ids" {
  description = "Isolated data subnets, one per Availability Zone."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.data_subnet_ids) >= 2
    error_message = "Data services require subnets in at least two Availability Zones."
  }
}

variable "availability_zones" {
  description = "Workload Availability Zones in order; a single-AZ database and the cache nodes are placed in them."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.availability_zones) >= 1
    error_message = "At least one Availability Zone is required."
  }
}

variable "client_security_group_id" {
  description = "Security group of the EKS nodes that may connect to PostgreSQL and Valkey."
  type        = string
  nullable    = false
}

variable "kms_key_arns" {
  description = "Regional KMS key ARNs by logical name; rds, valkey, and sqs are required."
  type        = map(string)
  nullable    = false

  validation {
    condition     = alltrue([for key_name in ["rds", "sqs", "valkey"] : contains(keys(var.kms_key_arns), key_name)])
    error_message = "The rds, sqs, and valkey KMS keys are required."
  }
}

variable "alert_topic_arn" {
  description = "Regional SNS topic that receives alarm and recovery notifications."
  type        = string
  nullable    = false
}

variable "database" {
  description = "PostgreSQL settings."
  type = object({
    name                  = string
    master_username       = string
    engine_version        = string
    instance_class        = string
    allocated_storage     = number
    max_allocated_storage = number
    multi_az              = bool
    backup_retention_days = number
    deletion_protection   = bool
    skip_final_snapshot   = bool
    apply_immediately     = bool
  })
  nullable = false

  validation {
    condition = (
      can(regex("^[A-Za-z][A-Za-z0-9_]*$", var.database.name)) &&
      can(regex("^[A-Za-z][A-Za-z0-9_]*$", var.database.master_username)) &&
      can(regex("^[0-9]+(\\.[0-9]+)?$", var.database.engine_version)) &&
      var.database.allocated_storage >= 20 &&
      var.database.max_allocated_storage >= var.database.allocated_storage &&
      var.database.backup_retention_days >= 1 &&
      var.database.backup_retention_days <= 35
    )
    error_message = "Use letter-first database and user names, a numeric engine version, at least 20 GiB of storage, and 1 to 35 days of backups; backups are required for cross-region replicas."
  }
}

variable "replication_source" {
  description = "Primary database that this region replicates as a disaster-recovery standby; null in the primary region."
  type = object({
    db_instance_arn                = string
    master_user_secret_arn         = string
    master_user_secret_kms_key_arn = string
  })
  default = null
}

variable "promote_replica" {
  description = "Whether the standby database stops replicating and becomes writable; set when this region becomes active."
  type        = bool
  default     = false
  nullable    = false
}

variable "cache" {
  description = "Valkey settings; Multi-AZ needs at least two workload Availability Zones."
  type = object({
    engine_version          = string
    node_type               = string
    num_cache_clusters      = number
    multi_az                = bool
    snapshot_retention_days = number
    log_retention_days      = number
    apply_immediately       = bool
  })
  nullable = false

  validation {
    condition = (
      can(regex("^[0-9]+\\.[0-9]+$", var.cache.engine_version)) &&
      var.cache.num_cache_clusters >= 1 &&
      (!var.cache.multi_az || (var.cache.num_cache_clusters >= 2 && length(var.availability_zones) >= 2)) &&
      var.cache.snapshot_retention_days >= 0 &&
      var.cache.snapshot_retention_days <= 35 &&
      var.cache.log_retention_days >= 1
    )
    error_message = "Use a major.minor engine version, at least two nodes and two workload Availability Zones for Multi-AZ, 0 to 35 snapshot days, and at least one log retention day."
  }
}

variable "queue" {
  description = "SQS job queue settings."
  type = object({
    visibility_timeout_seconds        = number
    message_retention_seconds         = number
    dlq_message_retention_seconds     = number
    receive_wait_time_seconds         = number
    max_receive_count                 = number
    kms_data_key_reuse_period_seconds = number
  })
  nullable = false

  validation {
    condition = (
      var.queue.visibility_timeout_seconds >= 0 && var.queue.visibility_timeout_seconds <= 43200 &&
      var.queue.message_retention_seconds >= 60 && var.queue.message_retention_seconds <= 1209600 &&
      var.queue.dlq_message_retention_seconds >= 60 && var.queue.dlq_message_retention_seconds <= 1209600 &&
      var.queue.receive_wait_time_seconds >= 0 && var.queue.receive_wait_time_seconds <= 20 &&
      var.queue.max_receive_count >= 1 && var.queue.max_receive_count <= 1000 &&
      var.queue.kms_data_key_reuse_period_seconds >= 60 && var.queue.kms_data_key_reuse_period_seconds <= 86400
    )
    error_message = "One or more SQS settings are outside the limits that SQS accepts."
  }
}

variable "alarms" {
  description = "CloudWatch alarm periods and thresholds."
  type = object({
    period_seconds                       = number
    evaluation_periods                   = number
    rds_cpu_threshold_percent            = number
    rds_free_storage_threshold_bytes     = number
    valkey_memory_threshold_percent      = number
    sqs_oldest_message_threshold_seconds = number
  })
  nullable = false

  validation {
    condition = (
      var.alarms.period_seconds >= 60 &&
      var.alarms.evaluation_periods >= 1 &&
      var.alarms.rds_cpu_threshold_percent > 0 && var.alarms.rds_cpu_threshold_percent <= 100 &&
      var.alarms.rds_free_storage_threshold_bytes > 0 &&
      var.alarms.valkey_memory_threshold_percent > 0 && var.alarms.valkey_memory_threshold_percent <= 100 &&
      var.alarms.sqs_oldest_message_threshold_seconds > 0
    )
    error_message = "Alarm periods must be at least 60 seconds, and thresholds must be positive percentages or values."
  }
}

variable "backup" {
  description = "AWS Backup schedule and retention for the database, and whether destroying the unit deletes its recovery points."
  type = object({
    schedule       = string
    retention_days = number
    force_destroy  = bool
  })
  nullable = false

  validation {
    condition     = can(regex("^cron\\(.+\\)$", var.backup.schedule)) && var.backup.retention_days >= 1 && var.backup.retention_days <= 35
    error_message = "The backup schedule must be a cron() expression, and continuous backups keep between 1 and 35 days."
  }
}
