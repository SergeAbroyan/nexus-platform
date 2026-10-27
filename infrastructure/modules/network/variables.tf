variable "name" {
  description = "Regional resource name prefix, such as nexus-dev-use1. Karpenter discovers subnets by this name."
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

variable "vpc" {
  description = "VPC address space and one public, private, and data subnet per Availability Zone."
  type = object({
    cidr                 = string
    availability_zones   = list(string)
    public_subnet_cidrs  = list(string)
    private_subnet_cidrs = list(string)
    data_subnet_cidrs    = list(string)
  })
  nullable = false

  validation {
    condition = (
      can(cidrnetmask(var.vpc.cidr)) &&
      length(var.vpc.availability_zones) >= 2 &&
      alltrue([
        for subnets in [var.vpc.public_subnet_cidrs, var.vpc.private_subnet_cidrs, var.vpc.data_subnet_cidrs] :
        length(subnets) == length(var.vpc.availability_zones) && alltrue([for cidr in subnets : can(cidrnetmask(cidr))])
      ])
    )
    error_message = "Provide a valid VPC CIDR, at least two Availability Zones, and one valid public, private, and data subnet CIDR per zone."
  }
}

variable "nat_gateway_mode" {
  description = "NAT gateway strategy: none, single, or one_per_az."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["none", "single", "one_per_az"], var.nat_gateway_mode)
    error_message = "The NAT gateway mode must be none, single, or one_per_az."
  }
}

variable "flow_logs" {
  description = "VPC Flow Log settings."
  type = object({
    enabled                  = bool
    retention_days           = number
    max_aggregation_interval = number
  })
  nullable = false

  validation {
    condition     = var.flow_logs.retention_days >= 1 && contains([60, 600], var.flow_logs.max_aggregation_interval)
    error_message = "Flow logs need at least one day of retention and an aggregation interval of 60 or 600 seconds."
  }
}
