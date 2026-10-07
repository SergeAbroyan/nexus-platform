locals {
  name                          = "${var.project_name}-${var.environment}"
  load_balancer_controller_name = "${local.name}-aws-load-balancer-controller"
  external_secrets_name         = "${local.name}-external-secrets"

  standard_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  })
}

module "load_balancer_controller" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.9.0"

  name            = local.load_balancer_controller_name
  use_name_prefix = false
  description     = "Pod Identity role for the Nexus AWS Load Balancer Controller"

  attach_aws_lb_controller_policy = true
  aws_lb_controller_policy_name   = local.load_balancer_controller_name

  associations = {
    controller = {
      cluster_name    = var.cluster_name
      namespace       = var.load_balancer_controller_namespace
      service_account = var.load_balancer_controller_service_account
    }
  }

  tags = local.standard_tags
}

module "external_secrets" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.9.0"

  name            = local.external_secrets_name
  use_name_prefix = false
  description     = "Pod Identity role for the Nexus External Secrets controller"

  attach_custom_policy      = true
  custom_policy_description = "Read-only access to the Nexus RDS credential secret"
  policy_statements = [
    {
      sid = "ReadDatabaseSecret"
      actions = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue",
        "secretsmanager:ListSecretVersionIds",
      ]
      resources = [var.rds_master_user_secret_arn]
    },
    {
      sid       = "DecryptDatabaseSecret"
      actions   = ["kms:Decrypt"]
      resources = [var.rds_kms_key_arn]
    },
  ]

  associations = {
    controller = {
      cluster_name    = var.cluster_name
      namespace       = var.external_secrets_namespace
      service_account = var.external_secrets_service_account
    }
  }

  tags = local.standard_tags
}
