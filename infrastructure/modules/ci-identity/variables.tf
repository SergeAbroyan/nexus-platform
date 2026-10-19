variable "project_name" {
  description = "Project name used in CI role names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "The project name must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment used in CI role names and tags."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.environment))
    error_message = "The environment must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "github_owner" {
  description = "GitHub user or organization that owns the trusted repositories."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$", var.github_owner))
    error_message = "The GitHub owner must be a valid user or organization name."
  }
}

variable "infrastructure_repository" {
  description = "GitHub repository allowed to deploy the infrastructure."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.infrastructure_repository))
    error_message = "The infrastructure repository name contains invalid characters."
  }
}

variable "applications_repository" {
  description = "GitHub repository allowed to publish application images."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.applications_repository))
    error_message = "The applications repository name contains invalid characters."
  }
}

variable "deployment_branch" {
  description = "Git branch trusted to obtain AWS deployment credentials."
  type        = string
  default     = "main"
  nullable    = false

  validation {
    condition     = length(trimspace(var.deployment_branch)) > 0 && !strcontains(var.deployment_branch, ":")
    error_message = "The deployment branch cannot be empty or contain a colon."
  }
}

variable "infrastructure_environment" {
  description = "GitHub Environment trusted to deploy infrastructure."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.infrastructure_environment)) > 0 && !strcontains(var.infrastructure_environment, ":")
    error_message = "The GitHub Environment cannot be empty or contain a colon."
  }
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs where application CI may push images."
  type        = set(string)
  nullable    = false

  validation {
    condition     = length(var.ecr_repository_arns) > 0 && alltrue([for arn in var.ecr_repository_arns : can(regex("^arn:[^:]+:ecr:[^:]+:[0-9]{12}:repository/.+$", arn))])
    error_message = "At least one valid ECR repository ARN is required."
  }
}

variable "terraform_state_bucket_name" {
  description = "S3 bucket containing this project's Terraform state."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.terraform_state_bucket_name))
    error_message = "The Terraform state bucket name must be a valid S3 bucket name."
  }
}

variable "tags" {
  description = "Additional tags merged with the module's standard tags."
  type        = map(string)
  default     = {}
  nullable    = false
}
