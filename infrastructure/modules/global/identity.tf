data "aws_partition" "current" {}

locals {
  partition                  = data.aws_partition.current.partition
  terraform_state_bucket_arn = "arn:${local.partition}:s3:::${var.terraform_state_bucket_name}"
}

module "github_oidc_provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-oidc-provider"
  version = "6.8.2"

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  tags = var.tags
}

module "application_ci" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.2"

  name            = "${var.name}-application-ci"
  use_name_prefix = false
  description     = "GitHub Actions role for publishing Nexus application images"

  enable_github_oidc = true
  oidc_subjects = [
    "${var.github.owner}/${var.github.applications_repository}:ref:refs/heads/${var.github.deployment_branch}",
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
      resources = [for repository in module.repository : repository.repository_arn]
    }
  }

  tags = var.tags

  depends_on = [module.github_oidc_provider]
}

module "infrastructure_ci" {
  for_each = var.environments

  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.8.2"

  name            = "${var.name}-${each.key}-infrastructure-ci"
  use_name_prefix = false
  description     = "GitHub Actions role for deploying the Nexus ${each.key} infrastructure"

  enable_github_oidc = true
  oidc_subjects = [
    "${var.github.owner}/${var.github.infrastructure_repository}:environment:${each.key}",
  ]

  create_inline_policy = true
  inline_policy_permissions = {
    ManageNexusInfrastructure = {
      actions = [
        "acm:*",
        "autoscaling:*",
        "budgets:*",
        "cloudfront:*",
        "cloudwatch:*",
        "ec2:*",
        "ecr:*",
        "eks:*",
        "elasticache:*",
        "elasticloadbalancing:*",
        "events:*",
        "fis:*",
        "guardduty:*",
        "iam:*",
        "kms:*",
        "logs:*",
        "rds:*",
        "route53:*",
        "secretsmanager:*",
        "sns:*",
        "sqs:*",
        "ssm:*",
        "wafv2:*",
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

  tags = var.tags

  depends_on = [module.github_oidc_provider]
}
