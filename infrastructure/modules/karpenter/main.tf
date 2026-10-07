locals {
  name = "${var.project_name}-${var.environment}-karpenter"
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.25.0"

  cluster_name = var.cluster_name

  create_pod_identity_association = true
  namespace                       = var.namespace
  service_account                 = var.service_account

  iam_role_name              = "${local.name}-controller"
  iam_role_use_name_prefix   = false
  iam_policy_name            = "${local.name}-controller"
  iam_policy_use_name_prefix = false

  node_iam_role_name                     = "${local.name}-node"
  node_iam_role_use_name_prefix          = false
  node_iam_role_source_account_condition = true
  node_iam_role_attach_cni_policy        = true

  iam_policy_statements = [
    {
      sid = "UseEncryptedNodeVolumes"
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:Encrypt",
        "kms:GenerateDataKeyWithoutPlaintext",
        "kms:ReEncryptFrom",
        "kms:ReEncryptTo",
      ]
      resources = [var.ebs_kms_key_arn]
    },
    {
      sid       = "CreateEncryptedNodeVolumeGrants"
      actions   = ["kms:CreateGrant"]
      resources = [var.ebs_kms_key_arn]
      condition = [{
        test     = "Bool"
        variable = "kms:GrantIsForAWSResource"
        values   = ["true"]
      }]
    },
  ]

  enable_spot_termination   = var.enable_spot_interruption
  queue_name                = local.name
  queue_managed_sse_enabled = true

  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  })
}
