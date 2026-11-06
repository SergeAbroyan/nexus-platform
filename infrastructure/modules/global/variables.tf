variable "name" {
  description = "Account-wide resource name prefix, such as nexus."
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

variable "standby_region" {
  description = "Region that receives replicated container images for disaster recovery."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]$", var.standby_region))
    error_message = "The standby region must be an AWS Region name, such as us-west-2."
  }
}

variable "domain_name" {
  description = "Public domain delegated to the Route 53 hosted zone."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.domain_name))
    error_message = "Set domain_name in infrastructure/live/account.hcl to a lowercase domain that you own."
  }
}

variable "domain_registered_with_route53" {
  description = "Whether the domain is registered with Route 53 in this account, so Terraform points its name servers at the hosted zone."
  type        = bool
  default     = false
  nullable    = false
}

variable "dns_force_destroy" {
  description = "Whether the hosted zone may be destroyed while it still contains records."
  type        = bool
  default     = false
  nullable    = false
}

variable "environments" {
  description = "Environments that receive an infrastructure CI role, each trusted only from the GitHub environment of the same name."
  type        = set(string)
  nullable    = false

  validation {
    condition     = length(var.environments) > 0 && alltrue([for environment in var.environments : can(regex("^[a-z][a-z0-9-]*$", environment))])
    error_message = "List at least one environment using lowercase letters, numbers, or hyphens."
  }
}

variable "github" {
  description = "GitHub owner, its permanent numeric ID, the repositories, and the branch trusted by the CI roles."
  type = object({
    owner                     = string
    owner_id                  = string
    infrastructure_repository = string
    applications_repository   = string
    gitops_repository         = string
    deployment_branch         = string
  })
  nullable = false

  validation {
    condition = alltrue([
      for value in values(var.github) : can(regex("^[A-Za-z0-9_.-]+$", value))
    ])
    error_message = "GitHub owner, repositories, and branch may contain only letters, numbers, dots, underscores, or hyphens."
  }
}

variable "terraform_state_bucket_name" {
  description = "S3 bucket that stores Terraform state for this account."
  type        = string
  nullable    = false
}

variable "ecr" {
  description = "Container registry settings shared by the primary and standby regions."
  type = object({
    namespace           = string
    repository_names    = set(string)
    force_delete        = bool
    maximum_image_count = number
  })
  nullable = false

  validation {
    condition = (
      can(regex("^[a-z][a-z0-9-]*$", var.ecr.namespace)) &&
      length(var.ecr.repository_names) > 0 &&
      alltrue([for name in var.ecr.repository_names : can(regex("^[a-z][a-z0-9-]*$", name))]) &&
      var.ecr.maximum_image_count >= 1
    )
    error_message = "ECR needs a lowercase namespace, at least one lowercase repository name, and positive retention settings."
  }
}

variable "budget" {
  description = "Monthly cost budget and the address that receives its alerts."
  type = object({
    monthly_limit_usd  = number
    notification_email = string
  })
  nullable = false

  validation {
    condition = (
      var.budget.monthly_limit_usd > 0 &&
      can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.budget.notification_email))
    )
    error_message = "The budget needs a positive monthly limit and a valid email address."
  }
}

variable "guardduty_enabled" {
  description = "Whether GuardDuty threat detection, EKS audit log monitoring, and EKS runtime monitoring run in the primary and standby regions."
  type        = bool
  default     = false
  nullable    = false
}

variable "audit" {
  description = "How long CloudTrail and AWS Config logs are kept, and whether destroying global also deletes them."
  type = object({
    retention_days = number
    force_destroy  = bool
  })
  nullable = false

  validation {
    condition     = var.audit.retention_days >= 90
    error_message = "Keep audit logs for at least 90 days."
  }
}

variable "security_hub_enabled" {
  description = "Whether AWS Config records resources and Security Hub checks them against the AWS Foundational Security Best Practices and CIS standards in both regions."
  type        = bool
  default     = false
  nullable    = false
}

variable "cloudflare" {
  description = "Cloudflare account that hosts the public DNS zone and the Zero Trust sign-in for admin tools, or null to keep DNS on Route 53 only. dns_authoritative points the registrar at Cloudflare."
  type = object({
    account_id        = string
    access_team       = string
    access_emails     = list(string)
    dns_authoritative = bool
  })
  default = null

  validation {
    condition = var.cloudflare == null ? true : (
      can(regex("^[0-9a-f]{32}$", var.cloudflare.account_id)) &&
      can(regex("^[a-z0-9][a-z0-9-]*$", var.cloudflare.access_team)) &&
      length(var.cloudflare.access_emails) > 0 &&
      alltrue([for email in var.cloudflare.access_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", email))])
    )
    error_message = "Set cloudflare in identity.hcl: the 32-character account ID, the Zero Trust team name, and at least one valid sign-in email address."
  }
}

variable "admin_access" {
  description = "Environments whose admin tools are published through a Cloudflare Tunnel behind Cloudflare Access, how long a sign-in lasts, and the in-cluster address of each tool."
  type = object({
    environments     = set(string)
    session_duration = string
    tools            = map(string)
  })
  nullable = false

  validation {
    condition = (
      alltrue([for environment in var.admin_access.environments : can(regex("^[a-z][a-z0-9-]*$", environment))]) &&
      can(regex("^[0-9]+(m|h)$", var.admin_access.session_duration)) &&
      alltrue([for tool, address in var.admin_access.tools : can(regex("^[a-z][a-z0-9-]*$", tool)) && can(regex("^http://[a-z0-9.-]+:[0-9]+$", address))])
    )
    error_message = "Admin access needs lowercase environment and tool names, a session duration such as 24h, and an http://<service>:<port> address for each tool."
  }
}
