locals {
  workload_availability_zones = slice(var.vpc.availability_zones, 0, var.availability_zone_count)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.3"

  name = var.name
  cidr = var.vpc.cidr

  azs              = var.vpc.availability_zones
  public_subnets   = var.vpc.public_subnet_cidrs
  private_subnets  = var.vpc.private_subnet_cidrs
  database_subnets = var.vpc.data_subnet_cidrs

  enable_dns_support   = true
  enable_dns_hostnames = true

  enable_nat_gateway     = var.nat_gateway_mode != "none"
  single_nat_gateway     = var.nat_gateway_mode == "single"
  one_nat_gateway_per_az = var.nat_gateway_mode == "one_per_az"

  map_public_ip_on_launch = false

  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  create_database_subnet_group       = false
  create_database_subnet_route_table = true
  create_database_nat_gateway_route  = false

  enable_flow_log                                 = var.flow_logs.enabled
  create_flow_log_cloudwatch_log_group            = var.flow_logs.enabled
  create_flow_log_cloudwatch_iam_role             = var.flow_logs.enabled
  flow_log_destination_type                       = "cloud-watch-logs"
  flow_log_traffic_type                           = "ALL"
  flow_log_max_aggregation_interval               = var.flow_logs.max_aggregation_interval
  flow_log_cloudwatch_log_group_retention_in_days = var.flow_logs.retention_days

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  private_subnet_tags_per_az = {
    for zone in local.workload_availability_zones : zone => {
      "karpenter.sh/discovery" = var.name
    }
  }

  tags = var.tags
}

data "aws_vpc_endpoint_service" "s3" {
  service      = "s3"
  service_type = "Gateway"
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = data.aws_vpc_endpoint_service.s3.service_name
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(module.vpc.private_route_table_ids, module.vpc.database_route_table_ids)

  tags = merge(var.tags, { Name = "${var.name}-s3" })
}
