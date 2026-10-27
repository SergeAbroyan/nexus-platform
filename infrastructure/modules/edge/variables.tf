variable "name" {
  description = "Environment-wide resource name prefix, such as nexus-dev."
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

variable "region" {
  description = "Region of the AWS provider for this unit; CloudFront certificates and WAF web ACLs must be in us-east-1."
  type        = string
  nullable    = false

  validation {
    condition     = var.region == "us-east-1"
    error_message = "The edge unit must run in us-east-1, the home region of CloudFront certificates and WAF web ACLs."
  }
}

variable "zone_id" {
  description = "Route 53 hosted-zone ID that validates the certificate and holds the application aliases."
  type        = string
  nullable    = false
}

variable "zone_name" {
  description = "Name of the Route 53 hosted zone."
  type        = string
  nullable    = false
}

variable "hostname" {
  description = "Public application hostname served by CloudFront."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.hostname))
    error_message = "Set domain_name in infrastructure/live/account.hcl so the hostname is a valid DNS name."
  }
}

variable "origins" {
  description = "Internal ingress load balancer of each region, keyed by region name."
  type = map(object({
    load_balancer_arn = string
    domain_name       = string
  }))
  nullable = false

  validation {
    condition     = length(var.origins) > 0
    error_message = "At least one regional origin is required."
  }
}

variable "active_region" {
  description = "Region whose origin receives all traffic; change it to fail over."
  type        = string
  nullable    = false

  validation {
    condition     = contains(keys(var.origins), var.active_region)
    error_message = "The active region must be one of the regional origins."
  }
}

variable "api_path_pattern" {
  description = "CloudFront path pattern that bypasses caching for API requests."
  type        = string
  default     = "/api/*"
  nullable    = false
}

variable "price_class" {
  description = "CloudFront edge-location price class."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "The CloudFront price class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "waf_rate_limit_per_five_minutes" {
  description = "Maximum requests allowed from one IP during the WAF five-minute evaluation window."
  type        = number
  nullable    = false

  validation {
    condition     = var.waf_rate_limit_per_five_minutes >= 100
    error_message = "The WAF rate limit must be at least 100 requests per five minutes."
  }
}
