variable "name" {
  description = "Regional resource name prefix, also used as the EKS cluster name, such as nexus-dev-use1."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.name))
    error_message = "The name must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "tags" {
  description = "Tags added to every resource, including EC2 instances launched by the node group."
  type        = map(string)
  default     = {}
  nullable    = false
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
  description = "ID of the VPC that contains the cluster."
  type        = string
  nullable    = false
}

variable "vpc_cidr_block" {
  description = "VPC CIDR from which the internal ingress load balancer reaches gateway pods."
  type        = string
  nullable    = false

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr_block))
    error_message = "The VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "private_subnet_ids" {
  description = "Private subnets, one per Availability Zone, used by the EKS control plane."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "EKS requires private subnets in at least two Availability Zones."
  }
}

variable "node_subnet_ids" {
  description = "Private subnets in the workload Availability Zones, used by the managed node group."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.node_subnet_ids) >= 1
    error_message = "At least one node subnet is required."
  }
}

variable "cluster_encryption_key_arn" {
  description = "KMS key ARN used to encrypt Kubernetes secrets."
  type        = string
  nullable    = false
}

variable "ebs_encryption_key_arn" {
  description = "KMS key ARN used for node volumes and EBS CSI persistent volumes."
  type        = string
  nullable    = false
}

variable "admin_principal_arns" {
  description = "IAM principal ARNs granted cluster administrator access."
  type        = set(string)
  nullable    = false

  validation {
    condition     = length(var.admin_principal_arns) > 0
    error_message = "At least one cluster administrator principal ARN is required."
  }
}

variable "endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public Kubernetes API endpoint."
  type        = list(string)
  nullable    = false

  validation {
    condition = (
      length(var.endpoint_public_access_cidrs) > 0 &&
      alltrue([for cidr in var.endpoint_public_access_cidrs : can(cidrnetmask(cidr))])
    )
    error_message = "The public Kubernetes API needs at least one valid CIDR block."
  }
}

variable "deletion_protection" {
  description = "Whether AWS prevents accidental deletion of the cluster."
  type        = bool
  nullable    = false
}

variable "control_plane_log_retention_days" {
  description = "Days CloudWatch retains EKS control-plane logs."
  type        = number
  nullable    = false

  validation {
    condition     = var.control_plane_log_retention_days >= 1
    error_message = "Control-plane logs must be retained for at least one day."
  }
}

variable "node_group" {
  description = "Managed node group that runs platform controllers across Availability Zones."
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

variable "karpenter" {
  description = "Kubernetes identity of the Karpenter controller and whether Spot interruption handling is enabled."
  type = object({
    namespace                = string
    service_account          = string
    enable_spot_interruption = bool
  })
  nullable = false
}

variable "ingress_port" {
  description = "Container port of the Istio ingress gateway that receives load balancer traffic."
  type        = number
  nullable    = false

  validation {
    condition     = var.ingress_port >= 1024 && var.ingress_port <= 65535
    error_message = "The ingress port must be an unprivileged port between 1024 and 65535."
  }
}
