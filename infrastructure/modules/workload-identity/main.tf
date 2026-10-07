locals {
  name = "${var.project_name}-${var.environment}"

  standard_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  })
}

module "api" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.9.0"

  name            = "${local.name}-api"
  use_name_prefix = false
  description     = "Pod Identity role for the Nexus API"

  attach_custom_policy      = true
  custom_policy_description = "Least-privilege AWS access for the Nexus API"
  policy_statements = [
    {
      sid       = "SendJobs"
      actions   = ["sqs:SendMessage"]
      resources = [var.sqs_queue_arn]
    },
    {
      sid = "EncryptQueueMessages"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey",
      ]
      resources = [var.sqs_kms_key_arn]
    },
    {
      sid       = "ConnectToValkey"
      actions   = ["elasticache:Connect"]
      resources = [var.valkey_replication_group_arn, var.valkey_user_arn]
    },
  ]

  associations = {
    api = {
      cluster_name    = var.cluster_name
      namespace       = var.namespace
      service_account = var.api_service_account
    }
  }

  tags = local.standard_tags
}

module "worker" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.9.0"

  name            = "${local.name}-worker"
  use_name_prefix = false
  description     = "Pod Identity role for the Nexus worker"

  attach_custom_policy      = true
  custom_policy_description = "Least-privilege AWS access for the Nexus worker"
  policy_statements = [
    {
      sid = "ConsumeJobs"
      actions = [
        "sqs:ChangeMessageVisibility",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ReceiveMessage",
      ]
      resources = [var.sqs_queue_arn]
    },
    {
      sid       = "DecryptQueueMessages"
      actions   = ["kms:Decrypt"]
      resources = [var.sqs_kms_key_arn]
    },
  ]

  associations = {
    worker = {
      cluster_name    = var.cluster_name
      namespace       = var.namespace
      service_account = var.worker_service_account
    }
  }

  tags = local.standard_tags
}
