data "aws_caller_identity" "current" {}

locals {
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.ecr.untagged_image_retention_days
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Retain only the newest images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.ecr.maximum_image_count
        }
        action = {
          type = "expire"
        }
      },
    ]
  })
}

module "repository" {
  for_each = var.ecr.repository_names

  source  = "terraform-aws-modules/ecr/aws"
  version = "3.2.0"

  repository_name                 = "${var.ecr.namespace}/${each.key}"
  repository_type                 = "private"
  repository_image_tag_mutability = "IMMUTABLE"
  repository_image_scan_on_push   = true
  repository_encryption_type      = "KMS"
  repository_force_delete         = var.ecr.force_delete

  attach_repository_policy    = false
  create_lifecycle_policy     = true
  repository_lifecycle_policy = local.repository_lifecycle_policy

  tags = merge(var.tags, { Service = each.key })
}

module "standby_repository" {
  for_each = var.ecr.repository_names

  source  = "terraform-aws-modules/ecr/aws"
  version = "3.2.0"

  region = var.standby_region

  repository_name                 = "${var.ecr.namespace}/${each.key}"
  repository_type                 = "private"
  repository_image_tag_mutability = "IMMUTABLE"
  repository_image_scan_on_push   = true
  repository_encryption_type      = "KMS"
  repository_force_delete         = var.ecr.force_delete

  attach_repository_policy    = false
  create_lifecycle_policy     = true
  repository_lifecycle_policy = local.repository_lifecycle_policy

  tags = merge(var.tags, { Service = each.key })
}

module "replication" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "3.2.0"

  create_repository                         = false
  create_registry_replication_configuration = true
  registry_replication_rules = [
    {
      destinations = [
        {
          region      = var.standby_region
          registry_id = data.aws_caller_identity.current.account_id
        },
      ]
      repository_filters = [
        {
          filter      = "${var.ecr.namespace}/"
          filter_type = "PREFIX_MATCH"
        },
      ]
    },
  ]

  tags = var.tags

  depends_on = [module.standby_repository]
}
