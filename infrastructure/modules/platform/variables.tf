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

variable "region" {
  description = "AWS Region of this cluster."
  type        = string
  nullable    = false
}

variable "environment" {
  description = "Environment whose GitOps values Argo CD loads, such as dev."
  type        = string
  nullable    = false
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  nullable    = false
}

variable "vpc_id" {
  description = "ID of the cluster VPC."
  type        = string
  nullable    = false
}

variable "vpc_cidr_block" {
  description = "VPC CIDR allowed to reach the internal ingress load balancer, which includes CloudFront VPC origin interfaces."
  type        = string
  nullable    = false
}

variable "load_balancer_subnet_ids" {
  description = "Private subnets in the workload Availability Zones for the internal ingress load balancer."
  type        = list(string)
  nullable    = false

  validation {
    condition     = length(var.load_balancer_subnet_ids) >= 1
    error_message = "The ingress load balancer needs at least one subnet."
  }
}

variable "karpenter" {
  description = "Karpenter node role, interruption queue, and the service account bound to its controller role."
  type = object({
    node_iam_role_name      = string
    interruption_queue_name = string
    service_account = object({
      namespace = string
      name      = string
    })
  })
  nullable = false
}

variable "kms_key_arns" {
  description = "Regional KMS key ARNs by logical name; ebs, secrets, sns, and sqs are required."
  type        = map(string)
  nullable    = false

  validation {
    condition     = alltrue([for key_name in ["ebs", "secrets", "sns", "sqs"] : contains(keys(var.kms_key_arns), key_name)])
    error_message = "The ebs, secrets, sns, and sqs KMS keys are required."
  }
}

variable "grafana_admin_secret_arn" {
  description = "Secrets Manager ARN of the Grafana administrator password."
  type        = string
  nullable    = false
}

variable "alert_topic_arn" {
  description = "Regional SNS topic that receives Alertmanager notifications."
  type        = string
  nullable    = false
}

variable "database" {
  description = "PostgreSQL connection settings and the secret that holds its password."
  type = object({
    host               = string
    port               = number
    name               = string
    username           = string
    secret_arn         = string
    secret_kms_key_arn = string
  })
  nullable = false

  validation {
    condition     = can(regex("^arn:[^:]+:secretsmanager:[a-z0-9-]+:[0-9]{12}:secret:.+$", var.database.secret_arn))
    error_message = "The database secret must be a Secrets Manager ARN."
  }
}

variable "cache" {
  description = "Valkey connection settings for the API."
  type = object({
    host                  = string
    port                  = number
    username              = string
    user_arn              = string
    replication_group_id  = string
    replication_group_arn = string
  })
  nullable = false
}

variable "queue" {
  description = "Job queue used by the API and worker, and the receive timings the worker uses."
  type = object({
    url                        = string
    arn                        = string
    receive_wait_time_seconds  = number
    visibility_timeout_seconds = number
  })
  nullable = false
}

variable "ecr_registry" {
  description = "Regional ECR registry hostname that hosts the application images."
  type        = string
  nullable    = false
}

variable "application_hostname" {
  description = "Public hostname accepted by the Istio gateway."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$", var.application_hostname))
    error_message = "Set domain_name in infrastructure/live/account.hcl so the application hostname is a valid DNS name."
  }
}

variable "ingress_port" {
  description = "Istio ingress gateway port that receives load balancer traffic."
  type        = number
  nullable    = false
}

variable "load_balancer_deletion_protection" {
  description = "Whether AWS prevents accidental deletion of the internal ingress load balancer."
  type        = bool
  nullable    = false
}

variable "argocd" {
  description = "Argo CD chart source, namespace, and component resources."
  type = object({
    namespace        = string
    chart_repository = string
    chart_version    = string
    controller_resources = object({
      requests = map(string)
      limits   = map(string)
    })
    server_resources = object({
      requests = map(string)
      limits   = map(string)
    })
    repository_server_resources = object({
      requests = map(string)
      limits   = map(string)
    })
  })
  nullable = false

  validation {
    condition = (
      can(regex("^https://", var.argocd.chart_repository)) &&
      can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.argocd.chart_version))
    )
    error_message = "Use an HTTPS chart repository and an exact semantic chart version."
  }
}

variable "gitops" {
  description = "Git repository and revision reconciled by Argo CD."
  type = object({
    repository = string
    revision   = string
  })
  nullable = false

  validation {
    condition     = can(regex("^https://", var.gitops.repository)) && length(trimspace(var.gitops.revision)) > 0
    error_message = "The GitOps repository must use HTTPS and the revision cannot be empty."
  }
}
