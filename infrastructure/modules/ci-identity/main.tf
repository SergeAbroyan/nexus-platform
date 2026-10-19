data "aws_partition" "current" {}

locals {
  name                       = "${var.project_name}-${var.environment}"
  github_oidc_url            = "https://token.actions.githubusercontent.com"
  terraform_state_bucket_arn = "arn:${data.aws_partition.current.partition}:s3:::${var.terraform_state_bucket_name}"

  standard_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  })
}

module "github_oidc_provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-oidc-provider"
  version = "6.8.2"

  url            = local.github_oidc_url
  client_id_list = ["sts.amazonaws.com"]

  tags = local.standard_tags
}

module "application_ci" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.2"

  name            = "${local.name}-application-ci"
  use_name_prefix = false
  description     = "GitHub Actions role for publishing Nexus application images"

  enable_github_oidc = true
  oidc_subjects = [
    "${var.github_owner}/${var.applications_repository}:ref:refs/heads/${var.deployment_branch}",
  ]

  create_inline_policy = true
  inline_policy_permissions = {
    GetEcrAuthorizationToken = {
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    }
    PushApplicationImages = {
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeImages",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
      ]
      resources = var.ecr_repository_arns
    }
  }

  tags = local.standard_tags

  depends_on = [module.github_oidc_provider]
}

module "infrastructure_ci" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.2"

  name            = "${local.name}-infrastructure-ci"
  use_name_prefix = false
  description     = "GitHub Actions role for deploying Nexus AWS infrastructure"

  enable_github_oidc = true
  oidc_subjects = [
    "${var.github_owner}/${var.infrastructure_repository}:environment:${var.infrastructure_environment}",
  ]

  create_inline_policy = true
  inline_policy_permissions = {
    ManageNexusInfrastructure = {
      actions = [
        "acm:*",
        "autoscaling:*",
        "budgets:*",
        "cloudwatch:*",
        "ec2:*",
        "ecr:*",
        "eks:*",
        "elasticache:*",
        "events:*",
        "iam:*",
        "kms:*",
        "logs:*",
        "rds:*",
        "route53:*",
        "secretsmanager:*",
        "sns:*",
        "sqs:*",
        "ssm:*",
      ]
      resources = ["*"]
    }
    ReadTerraformStateBucket = {
      actions = [
        "s3:GetBucketLocation",
        "s3:ListBucket",
      ]
      resources = [local.terraform_state_bucket_arn]
    }
    ManageTerraformStateObjects = {
      actions = [
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:PutObject",
      ]
      resources = ["${local.terraform_state_bucket_arn}/*"]
    }
  }

  tags = local.standard_tags

  depends_on = [module.github_oidc_provider]
}
