variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "The project name must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment, such as dev, staging, or production."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.environment))
    error_message = "The environment must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block assigned to the VPC."
  type        = string
  nullable    = false

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "The VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "Availability Zones across which subnets are distributed."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two Availability Zones are required for high availability."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public load balancers and NAT gateways."
  type        = list(string)
  nullable    = false

  validation {
    condition = (
      length(var.public_subnet_cidrs) == length(var.availability_zones) &&
      alltrue([for cidr in var.public_subnet_cidrs : can(cidrnetmask(cidr))])
    )
    error_message = "Provide one valid public subnet CIDR for each Availability Zone."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private application and Kubernetes workloads."
  type        = list(string)
  nullable    = false

  validation {
    condition = (
      length(var.private_subnet_cidrs) == length(var.availability_zones) &&
      alltrue([for cidr in var.private_subnet_cidrs : can(cidrnetmask(cidr))])
    )
    error_message = "Provide one valid private subnet CIDR for each Availability Zone."
  }
}

variable "data_subnet_cidrs" {
  description = "CIDR blocks for isolated database and cache workloads."
  type        = list(string)
  nullable    = false

  validation {
    condition = (
      length(var.data_subnet_cidrs) == length(var.availability_zones) &&
      alltrue([for cidr in var.data_subnet_cidrs : can(cidrnetmask(cidr))])
    )
    error_message = "Provide one valid data subnet CIDR for each Availability Zone."
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

variable "enable_flow_logs" {
  description = "Whether to record VPC network traffic in CloudWatch Logs."
  type        = bool
  default     = true
  nullable    = false
}

variable "flow_log_retention_days" {
  description = "Number of days CloudWatch retains VPC Flow Log records."
  type        = number
  default     = 30
  nullable    = false

  validation {
    condition     = var.flow_log_retention_days >= 1
    error_message = "VPC Flow Logs must be retained for at least one day."
  }
}

variable "flow_log_max_aggregation_interval" {
  description = "Maximum number of seconds aggregated into each VPC Flow Log record."
  type        = number
  default     = 600
  nullable    = false

  validation {
    condition     = contains([60, 600], var.flow_log_max_aggregation_interval)
    error_message = "The Flow Log aggregation interval must be 60 or 600 seconds."
  }
}

variable "tags" {
  description = "Additional tags merged with the module's standard tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
