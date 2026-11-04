data "aws_partition" "current" {}

data "aws_iam_policy_document" "backup_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  count = local.replicating ? 0 : 1

  name               = "${var.name}-backup"
  description        = "Role that AWS Backup assumes to back up and restore the ${var.name} database"
  assume_role_policy = data.aws_iam_policy_document.backup_trust.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  for_each = local.replicating ? toset([]) : toset([
    "AWSBackupServiceRolePolicyForBackup",
    "AWSBackupServiceRolePolicyForRestores",
  ])

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/${each.key}"
}

resource "aws_backup_vault" "database" {
  count = local.replicating ? 0 : 1

  name          = "${var.name}-database"
  kms_key_arn   = var.kms_key_arns["rds"]
  force_destroy = var.backup.force_destroy

  tags = var.tags
}

resource "aws_backup_plan" "database" {
  count = local.replicating ? 0 : 1

  name = "${var.name}-database"

  rule {
    rule_name                = "daily"
    target_vault_name        = aws_backup_vault.database[0].name
    schedule                 = var.backup.schedule
    start_window             = 60
    completion_window        = 180
    enable_continuous_backup = true

    lifecycle {
      delete_after = var.backup.retention_days
    }
  }

  tags = var.tags
}

resource "aws_backup_selection" "database" {
  count = local.replicating ? 0 : 1

  name         = "${var.name}-database"
  plan_id      = aws_backup_plan.database[0].id
  iam_role_arn = aws_iam_role.backup[0].arn
  resources    = [module.database.db_instance_arn]
}
