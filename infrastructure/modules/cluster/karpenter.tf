module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.25.0"

  cluster_name = module.eks.cluster_name

  create_pod_identity_association = true
  namespace                       = var.karpenter.namespace
  service_account                 = var.karpenter.service_account

  iam_role_name              = "${var.name}-karpenter-controller"
  iam_role_use_name_prefix   = false
  iam_policy_name            = "${var.name}-karpenter-controller"
  iam_policy_use_name_prefix = false

  node_iam_role_name                     = "${var.name}-karpenter-node"
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
      resources = [var.ebs_encryption_key_arn]
    },
    {
      sid       = "CreateEncryptedNodeVolumeGrants"
      actions   = ["kms:CreateGrant"]
      resources = [var.ebs_encryption_key_arn]
      condition = [{
        test     = "Bool"
        variable = "kms:GrantIsForAWSResource"
        values   = ["true"]
      }]
    },
  ]

  enable_spot_termination   = var.karpenter.enable_spot_interruption
  queue_name                = "${var.name}-karpenter"
  queue_managed_sse_enabled = true

  tags = var.tags
}
