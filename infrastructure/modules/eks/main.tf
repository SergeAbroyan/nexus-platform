data "aws_partition" "current" {}

locals {
  cluster_name = "${var.project_name}-${var.environment}"

  standard_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  })
}

module "ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.9.0"

  name = "${local.cluster_name}-ebs-csi"

  attach_aws_ebs_csi_policy = true
  aws_ebs_csi_kms_arns      = [var.ebs_encryption_key_arn]

  associations = {}

  tags = local.standard_tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.25.0"

  name               = local.cluster_name
  kubernetes_version = var.kubernetes_version

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = false

  access_entries = {
    for principal_arn in var.cluster_admin_principal_arns : principal_arn => {
      principal_arn = principal_arn

      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnet_ids
  control_plane_subnet_ids = var.private_subnet_ids

  endpoint_private_access      = true
  endpoint_public_access       = var.endpoint_public_access
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  encryption_config = {
    provider_key_arn = var.cluster_encryption_key_arn
    resources        = ["secrets"]
  }
  create_kms_key           = false
  attach_encryption_policy = true

  enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]
  cloudwatch_log_group_retention_in_days = var.control_plane_log_retention_days

  deletion_protection = var.deletion_protection
  upgrade_policy = {
    support_type = "STANDARD"
  }

  enable_irsa = false

  addons = {
    "aws-ebs-csi-driver" = {
      pod_identity_association = [{
        role_arn        = module.ebs_csi_pod_identity.iam_role_arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
    coredns = {}
    "eks-pod-identity-agent" = {
      before_compute = true
    }
    "kube-proxy" = {}
    "vpc-cni" = {
      before_compute = true
    }
  }

  eks_managed_node_groups = {
    system = {
      name                           = "${local.cluster_name}-system"
      subnet_ids                     = var.private_subnet_ids
      ami_type                       = "AL2023_x86_64_STANDARD"
      instance_types                 = var.node_group.instance_types
      capacity_type                  = var.node_group.capacity_type
      use_latest_ami_release_version = true
      iam_role_attach_cni_policy     = true
      min_size                       = var.node_group.min_size
      max_size                       = var.node_group.max_size
      desired_size                   = var.node_group.desired_size

      metadata_options = {
        http_endpoint               = "enabled"
        http_put_response_hop_limit = 1
        http_tokens                 = "required"
        instance_metadata_tags      = "disabled"
      }

      block_device_mappings = {
        root = {
          device_name = "/dev/xvda"
          ebs = {
            delete_on_termination = true
            encrypted             = true
            volume_size           = var.node_group.disk_size
            volume_type           = "gp3"
          }
        }
      }

      labels = {
        role = "system"
      }

      node_repair_config = {
        enabled = true
      }

      update_config = {
        max_unavailable = 1
      }
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }

  tags = local.standard_tags
}
