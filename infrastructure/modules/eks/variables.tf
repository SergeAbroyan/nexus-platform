variable "project_name" {
  description = "Project name used in EKS resource names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "The project name must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment used in EKS resource names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.environment))
    error_message = "The environment must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes major and minor version used by EKS."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.kubernetes_version))
    error_message = "The Kubernetes version must use major.minor format, for example 1.35."
  }
}

variable "vpc_id" {
  description = "ID of the VPC that contains the EKS cluster."
  type        = string
  nullable    = false
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the EKS control plane and worker nodes."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "EKS requires private subnets in at least two Availability Zones."
  }
}

variable "cluster_encryption_key_arn" {
  description = "KMS key ARN used to encrypt Kubernetes secrets."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$", var.cluster_encryption_key_arn))
    error_message = "The cluster encryption key must be a valid KMS key ARN."
  }
}

variable "cluster_admin_principal_arns" {
  description = "IAM principal ARNs granted cluster-wide administrator access."
  type        = set(string)
  nullable    = false

  validation {
    condition     = length(var.cluster_admin_principal_arns) > 0
    error_message = "At least one cluster administrator principal ARN is required."
  }
}

variable "endpoint_public_access" {
  description = "Whether the Kubernetes API is reachable through its public endpoint."
  type        = bool
  default     = true
  nullable    = false
}

variable "endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public Kubernetes API endpoint."
  type        = list(string)
  nullable    = false

  validation {
    condition = (
      !var.endpoint_public_access ||
      (
        length(var.endpoint_public_access_cidrs) > 0 &&
        alltrue([for cidr in var.endpoint_public_access_cidrs : can(cidrnetmask(cidr))])
      )
    )
    error_message = "Public endpoint access requires at least one valid CIDR block."
  }
}

variable "deletion_protection" {
  description = "Whether AWS prevents accidental deletion of the EKS cluster."
  type        = bool
  default     = true
  nullable    = false
}

variable "control_plane_log_retention_days" {
  description = "Number of days CloudWatch retains EKS control-plane logs."
  type        = number
  default     = 30
  nullable    = false

  validation {
    condition     = var.control_plane_log_retention_days >= 1
    error_message = "Control-plane logs must be retained for at least one day."
  }
}

variable "node_group" {
  description = "Configuration for the initial EKS managed node group."
  type = object({
    instance_types = list(string)
    capacity_type  = string
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size      = number
  })
  nullable = false

  validation {
    condition = (
      length(var.node_group.instance_types) > 0 &&
      contains(["ON_DEMAND", "SPOT"], var.node_group.capacity_type) &&
      var.node_group.min_size >= 0 &&
      var.node_group.min_size <= var.node_group.desired_size &&
      var.node_group.desired_size <= var.node_group.max_size &&
      var.node_group.disk_size >= 20
    )
    error_message = "The node group requires instance types, a valid capacity type, min <= desired <= max, and at least 20 GiB of disk."
  }
}

variable "tags" {
  description = "Additional tags merged with the module's standard tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
