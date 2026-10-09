variable "chart_repository" {
  description = "Helm repository containing the Argo CD chart."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^https://", var.chart_repository))
    error_message = "The Argo CD chart repository must use HTTPS."
  }
}

variable "chart_version" {
  description = "Pinned Argo CD Helm chart version."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.chart_version))
    error_message = "The Argo CD chart version must be an exact semantic version."
  }
}

variable "namespace" {
  description = "Kubernetes namespace where Argo CD is installed."
  type        = string
  default     = "argocd"
  nullable    = false
}

variable "gitops_repository" {
  description = "Git repository containing the Nexus Helm charts and environment values."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^https://", var.gitops_repository))
    error_message = "The GitOps repository must use HTTPS."
  }
}

variable "gitops_revision" {
  description = "Git revision reconciled by the Argo CD ApplicationSets."
  type        = string
  default     = "main"
  nullable    = false

  validation {
    condition     = length(trimspace(var.gitops_revision)) > 0
    error_message = "The GitOps revision cannot be empty."
  }
}

variable "cluster_name" {
  description = "EKS cluster name passed to cluster-aware GitOps components."
  type        = string
  nullable    = false
}

variable "aws_region" {
  description = "AWS region containing the EKS cluster."
  type        = string
  nullable    = false
}

variable "vpc_id" {
  description = "VPC ID used by the AWS Load Balancer Controller."
  type        = string
  nullable    = false
}

variable "karpenter_interruption_queue_name" {
  description = "SQS queue used by Karpenter for interruption events."
  type        = string
  nullable    = false
}

variable "karpenter_node_iam_role_name" {
  description = "IAM role used by EC2 instances created by Karpenter."
  type        = string
  nullable    = false
}

variable "ebs_kms_key_arn" {
  description = "KMS key ARN passed to the Karpenter EC2 node class."
  type        = string
  nullable    = false
}

variable "environment" {
  description = "Deployment environment whose Helm values Argo CD loads."
  type        = string
  nullable    = false
}

variable "nexus_ingress_host" {
  description = "Host accepted by the internal Nexus Istio gateway; use an internal DNS name when available."
  type        = string
  default     = "*"
  nullable    = false

  validation {
    condition     = var.nexus_ingress_host == "*" || can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", var.nexus_ingress_host))
    error_message = "The Nexus ingress host must be '*' or a valid lowercase DNS hostname."
  }
}

variable "dns_zone_name" {
  description = "Route 53 zone in which ExternalDNS may manage records."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$", var.dns_zone_name))
    error_message = "The DNS zone name must be a valid lowercase DNS name."
  }
}

variable "nexus_certificate_arn" {
  description = "ACM certificate used by the Nexus Network Load Balancer HTTPS listener."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:acm:[^:]+:[0-9]{12}:certificate/.+$", var.nexus_certificate_arn))
    error_message = "The Nexus certificate must be a valid ACM certificate ARN."
  }
}

variable "ecr_registry_url" {
  description = "ECR registry hosting the Nexus application images."
  type        = string
  nullable    = false
}

variable "database_host" {
  description = "Private RDS hostname used by the Nexus API."
  type        = string
  nullable    = false
}

variable "database_port" {
  description = "RDS listener port."
  type        = number
  nullable    = false
}

variable "database_name" {
  description = "PostgreSQL database used by Nexus."
  type        = string
  nullable    = false
}

variable "database_username" {
  description = "PostgreSQL username paired with the RDS-managed password."
  type        = string
  nullable    = false
}

variable "database_secret_arn" {
  description = "Secrets Manager ARN containing the RDS-managed password."
  type        = string
  nullable    = false
}

variable "grafana_admin_secret_arn" {
  description = "Secrets Manager ARN containing the generated Grafana administrator password."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:[^:]+:secretsmanager:[^:]+:[0-9]{12}:secret:.+$", var.grafana_admin_secret_arn))
    error_message = "The Grafana administrator secret must be a valid Secrets Manager ARN."
  }
}

variable "valkey_host" {
  description = "Private Valkey primary endpoint used by the Nexus API."
  type        = string
  nullable    = false
}

variable "valkey_port" {
  description = "Valkey TLS listener port."
  type        = number
  nullable    = false
}

variable "valkey_username" {
  description = "IAM-enabled Valkey username used by the Nexus API."
  type        = string
  nullable    = false
}

variable "valkey_cache_name" {
  description = "Valkey replication group identifier used in IAM tokens."
  type        = string
  nullable    = false
}

variable "sqs_queue_url" {
  description = "SQS queue URL used by the Nexus API and worker."
  type        = string
  nullable    = false
}

variable "controller_resources" {
  description = "CPU and memory requests and limits for the Argo CD application controller."
  type = object({
    requests = map(string)
    limits   = map(string)
  })
  nullable = false
}

variable "server_resources" {
  description = "CPU and memory requests and limits for the Argo CD API server."
  type = object({
    requests = map(string)
    limits   = map(string)
  })
  nullable = false
}

variable "repository_server_resources" {
  description = "CPU and memory requests and limits for the Argo CD repository server."
  type = object({
    requests = map(string)
    limits   = map(string)
  })
  nullable = false
}
