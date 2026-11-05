locals {
  origin_port = 80
}

data "aws_ec2_managed_prefix_list" "cloudfront_origin_facing" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

module "ingress_load_balancer" {
  source  = "terraform-aws-modules/alb/aws"
  version = "10.5.1"

  name                             = "${var.name}-ingress"
  load_balancer_type               = "network"
  internal                         = true
  vpc_id                           = var.vpc_id
  subnets                          = var.load_balancer_subnet_ids
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = var.load_balancer_deletion_protection

  security_group_name = "${var.name}-ingress"
  security_group_ingress_rules = {
    origin_from_cloudfront = {
      description    = "CloudFront VPC origin traffic, which arrives from CloudFront's origin-facing addresses"
      from_port      = local.origin_port
      to_port        = local.origin_port
      ip_protocol    = "tcp"
      prefix_list_id = data.aws_ec2_managed_prefix_list.cloudfront_origin_facing.id
    }
  }
  security_group_egress_rules = {
    gateway_in_vpc = {
      description = "Istio ingress gateway pods"
      from_port   = var.ingress_port
      to_port     = var.ingress_port
      ip_protocol = "tcp"
      cidr_ipv4   = var.vpc_cidr_block
    }
  }

  listeners = {
    origin = {
      port     = local.origin_port
      protocol = "TCP"
      forward = {
        target_group_key = "gateway"
      }
    }
  }

  target_groups = {
    gateway = {
      name                 = "${var.name}-gateway"
      protocol             = "TCP"
      port                 = var.ingress_port
      target_type          = "ip"
      create_attachment    = false
      deregistration_delay = 30
      health_check = {
        enabled             = true
        protocol            = "TCP"
        port                = "traffic-port"
        interval            = 10
        healthy_threshold   = 2
        unhealthy_threshold = 2
      }
    }
  }

  tags = var.tags
}
