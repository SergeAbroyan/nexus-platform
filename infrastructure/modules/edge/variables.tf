variable "project_name" {
  description = "Project name used in edge resource names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "The project name must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment used in edge resource names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.environment))
    error_message = "The environment must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "enable_cdn" {
  description = "Creates CloudFront and its DNS records when true."
  type        = bool
  default     = false
  nullable    = false
}

variable "enable_cdn_origin_mode" {
  description = "Confirms that the origin load balancer is configured without an NLB TLS listener."
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = !var.enable_cdn || var.enable_cdn_origin_mode
    error_message = "CDN origin mode must be enabled before CloudFront can be enabled."
  }
}

variable "enable_waf" {
  description = "Attaches an AWS WAF web ACL to CloudFront when both this and enable_cdn are true."
  type        = bool
  default     = false
  nullable    = false

  validation {
    condition     = !var.enable_waf || var.enable_cdn
    error_message = "WAF cannot be enabled when the CDN is disabled."
  }
}

variable "hostname" {
  description = "Public application hostname served by CloudFront."
  type        = string
  nullable    = false

  validation {
    condition     = !var.enable_cdn || can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", var.hostname))
    error_message = "A valid lowercase DNS hostname is required when the CDN is enabled."
  }
}

variable "zone_name" {
  description = "Existing Route 53 public-zone name where the CloudFront aliases are created."
  type        = string
  nullable    = false

  validation {
    condition     = !var.enable_cdn || can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", var.zone_name))
    error_message = "A valid Route 53 public-zone name is required when the CDN is enabled."
  }
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the CloudFront viewer hostname; it must exist in us-east-1."
  type        = string
  nullable    = false

  validation {
    condition     = !var.enable_cdn || can(regex("^arn:[^:]+:acm:us-east-1:[0-9]{12}:certificate/.+$", var.certificate_arn))
    error_message = "CloudFront requires a valid ACM certificate ARN from us-east-1."
  }
}

variable "origin_load_balancer_arn" {
  description = "ARN of the private ALB or non-TLS NLB used as the CloudFront VPC origin."
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition     = !var.enable_cdn || can(regex("^arn:[^:]+:elasticloadbalancing:[^:]+:[0-9]{12}:loadbalancer/(app|net)/.+$", var.origin_load_balancer_arn))
    error_message = "A valid ALB or NLB ARN is required when the CDN is enabled."
  }
}

variable "origin_domain_name" {
  description = "DNS name of the private load balancer used as the CloudFront VPC origin."
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition     = !var.enable_cdn || can(regex("^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$", var.origin_domain_name))
    error_message = "A valid origin DNS name is required when the CDN is enabled."
  }
}

variable "origin_http_port" {
  description = "HTTP listener port on the private origin."
  type        = number
  default     = 80
  nullable    = false

  validation {
    condition     = var.origin_http_port >= 1 && var.origin_http_port <= 65535
    error_message = "The origin HTTP port must be between 1 and 65535."
  }
}

variable "origin_https_port" {
  description = "HTTPS listener port on the private origin."
  type        = number
  default     = 443
  nullable    = false

  validation {
    condition     = var.origin_https_port >= 1 && var.origin_https_port <= 65535
    error_message = "The origin HTTPS port must be between 1 and 65535."
  }
}

variable "origin_protocol_policy" {
  description = "Protocol CloudFront uses to connect to the VPC origin."
  type        = string
  default     = "http-only"
  nullable    = false

  validation {
    condition     = contains(["http-only", "https-only", "match-viewer"], var.origin_protocol_policy)
    error_message = "The origin protocol policy must be http-only, https-only, or match-viewer."
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
  default     = "PriceClass_100"
  nullable    = false

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "The CloudFront price class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "waf_rate_limit_per_five_minutes" {
  description = "Maximum requests allowed from one IP during the WAF five-minute evaluation window."
  type        = number
  default     = 2000
  nullable    = false

  validation {
    condition     = var.waf_rate_limit_per_five_minutes >= 100
    error_message = "The WAF rate limit must be at least 100 requests per five minutes."
  }
}

variable "tags" {
  description = "Additional tags merged with the module's standard tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
