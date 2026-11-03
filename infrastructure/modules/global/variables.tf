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
  description = "GitHub owner, repositories, and the branch trusted by the CI roles."
  type = object({
    owner                     = string
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

variable "scheduled_environments" {
  description = "Environments that a GitHub Actions workflow stops outside working hours and starts again."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition     = length(setsubtract(var.scheduled_environments, var.environments)) == 0
    error_message = "Every scheduled environment must also be listed in environments."
  }
}

variable "guardduty_enabled" {
  description = "Whether GuardDuty threat detection, EKS audit log monitoring, and EKS runtime monitoring run in the primary and standby regions."
  type        = bool
  default     = false
  nullable    = false
}
