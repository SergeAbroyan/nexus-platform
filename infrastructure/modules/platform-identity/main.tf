locals {
  name = "${var.project_name}-${var.environment}-aws-load-balancer-controller"

  standard_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  })
}

module "load_balancer_controller" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.9.0"

  name            = local.name
  use_name_prefix = false
  description     = "Pod Identity role for the Nexus AWS Load Balancer Controller"

  attach_aws_lb_controller_policy = true
  aws_lb_controller_policy_name   = local.name

  associations = {
    controller = {
      cluster_name    = var.cluster_name
      namespace       = var.load_balancer_controller_namespace
      service_account = var.load_balancer_controller_service_account
    }
  }

  tags = local.standard_tags
}
