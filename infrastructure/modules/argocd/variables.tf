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
  description = "Git repository containing the Nexus root application chart."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^https://", var.gitops_repository))
    error_message = "The GitOps repository must use HTTPS."
  }
}

variable "gitops_revision" {
  description = "Git revision reconciled by the root Argo CD application."
  type        = string
  default     = "main"
  nullable    = false

  validation {
    condition     = length(trimspace(var.gitops_revision)) > 0
    error_message = "The GitOps revision cannot be empty."
  }
}

variable "gitops_chart_path" {
  description = "Path to the root application Helm chart inside the GitOps repository."
  type        = string
  default     = "bootstrap/root"
  nullable    = false

  validation {
    condition     = length(trimspace(var.gitops_chart_path)) > 0 && !startswith(var.gitops_chart_path, "/")
    error_message = "The GitOps chart path must be a non-empty relative path."
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
