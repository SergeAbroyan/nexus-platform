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

variable "ecr_namespace" {
  description = "ECR repository namespace of the Nexus images, which Kyverno may read to verify their signatures."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.ecr_namespace))
    error_message = "The ECR namespace must start with a lowercase letter and contain only lowercase letters, numbers, or hyphens."
  }
}

variable "ci_identity" {
  description = "GitHub Actions workflow identity whose keyless cosign signature every Nexus image must carry."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^https://github\\.com/[^/]+/[^/]+/\\.github/workflows/[^@]+@refs/heads/.+$", var.ci_identity))
    error_message = "The CI identity must be a workflow URL such as https://github.com/owner/repository/.github/workflows/ci.yaml@refs/heads/main."
  }
}

variable "slack_webhook_secret_name" {
  description = "Secrets Manager secret, in every region, that holds the Slack incoming webhook URL for Alertmanager."
  type        = string
  nullable    = false
}

variable "github_sso" {
  description = "Argo CD sign-in with GitHub through Dex: the OAuth app client ID, the Secrets Manager secret with its client secret, and the GitHub logins that become administrators."
  type = object({
    enabled            = bool
    client_id          = string
    client_secret_name = string
    admin_logins       = list(string)
  })
  nullable = false

  validation {
    condition     = !var.github_sso.enabled || (length(trimspace(var.github_sso.client_id)) > 0 && length(var.github_sso.admin_logins) > 0)
    error_message = "GitHub sign-in needs the OAuth app client ID and at least one administrator login."
  }
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

variable "backup_bucket_force_destroy" {
  description = "Whether destroying the platform unit also deletes the Velero backups in its bucket."
  type        = bool
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
    secrets_revision = number
  })
  nullable = false

  validation {
    condition = (
      can(regex("^https://", var.argocd.chart_repository)) &&
      can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.argocd.chart_version))
    )
    error_message = "Use an HTTPS chart repository and an exact semantic chart version."
  }

  validation {
    condition     = var.argocd.secrets_revision >= 1 && floor(var.argocd.secrets_revision) == var.argocd.secrets_revision
    error_message = "Increase secrets_revision by one, starting at 1, each time the deploy key or the GitHub OAuth client secret changes."
  }
}

variable "gitops" {
  description = "GitOps repository and revision that Argo CD reconciles, and the Secrets Manager secret with its read-only deploy key."
  type = object({
    repository             = string
    revision               = string
    deploy_key_secret_name = string
  })
  nullable = false

  validation {
    condition     = can(regex("^git@", var.gitops.repository)) && length(trimspace(var.gitops.revision)) > 0
    error_message = "The GitOps repository must be an SSH URL such as git@github.com:owner/repository.git, and the revision cannot be empty."
  }
}

variable "admin_access" {
  description = "Cloudflare Tunnel for this environment's admin tools: the Secrets Manager secret that holds its token and the public address of each tool, or null when admin tools are reached only with kubectl port-forward."
  type = object({
    tunnel_id                = string
    tunnel_token_secret_name = string
    hostnames                = map(string)
  })
  default = null
}
