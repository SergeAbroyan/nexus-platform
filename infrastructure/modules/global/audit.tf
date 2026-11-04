locals {
  trail_name = "${var.name}-account"
  trail_arn  = "arn:${local.partition}:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/${local.trail_name}"
  audit_logs = "arn:${local.partition}:s3:::${var.name}-audit-${data.aws_caller_identity.current.account_id}"
}

module "audit_key" {
  source  = "terraform-aws-modules/kms/aws"
  version = "4.2.2"

  description             = "${var.name} CloudTrail log encryption key"
  key_usage               = "ENCRYPT_DECRYPT"
  key_spec                = "SYMMETRIC_DEFAULT"
  enable_default_policy   = true
  enable_key_rotation     = true
  multi_region            = false
  deletion_window_in_days = 7

  key_statements = [
    {
      sid       = "AllowCloudTrailToEncryptLogs"
      actions   = ["kms:GenerateDataKey*"]
      resources = ["*"]
      principals = [{
        type        = "Service"
        identifiers = ["cloudtrail.amazonaws.com"]
      }]
      condition = [
        {
          test     = "StringEquals"
          variable = "aws:SourceArn"
          values   = [local.trail_arn]
        },
        {
          test     = "StringLike"
          variable = "kms:EncryptionContext:aws:cloudtrail:arn"
          values   = ["arn:${local.partition}:cloudtrail:*:${data.aws_caller_identity.current.account_id}:trail/*"]
        },
      ]
    },
    {
      sid       = "AllowCloudTrailToDescribeKey"
      actions   = ["kms:DescribeKey"]
      resources = ["*"]
      principals = [{
        type        = "Service"
        identifiers = ["cloudtrail.amazonaws.com"]
      }]
    },
  ]

  computed_aliases = {
    this = {
      name = "${var.name}/audit"
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-audit" })
}

data "aws_iam_policy_document" "audit_logs" {
  statement {
    sid       = "CloudTrailAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = [local.audit_logs]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid       = "CloudTrailWrite"
    actions   = ["s3:PutObject"]
    resources = ["${local.audit_logs}/cloudtrail/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid       = "ConfigAclCheck"
    actions   = ["s3:GetBucketAcl", "s3:ListBucket"]
    resources = [local.audit_logs]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid       = "ConfigWrite"
    actions   = ["s3:PutObject"]
    resources = ["${local.audit_logs}/config/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

module "audit_logs" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.17.0"

  bucket        = "${var.name}-audit-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.audit.force_destroy

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  attach_policy                         = true
  policy                                = data.aws_iam_policy_document.audit_logs.json
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule = [
    {
      id      = "expire-audit-logs"
      enabled = true

      expiration = {
        days = var.audit.retention_days
      }

      noncurrent_version_expiration = {
        noncurrent_days = 30
      }
    },
  ]

  tags = merge(var.tags, { Name = "${var.name}-audit" })
}

resource "aws_cloudtrail" "account" {
  name                          = local.trail_name
  s3_bucket_name                = module.audit_logs.s3_bucket_id
  s3_key_prefix                 = "cloudtrail"
  kms_key_id                    = module.audit_key.key_arn
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  tags = var.tags

  depends_on = [module.audit_logs]
}

resource "aws_accessanalyzer_analyzer" "account" {
  for_each = local.account_regions

  region        = each.key
  analyzer_name = "${var.name}-account"
  type          = "ACCOUNT"

  tags = var.tags
}
