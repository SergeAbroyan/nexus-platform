output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "IPv4 CIDR block assigned to the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "IDs of the private application subnets."
  value       = module.vpc.private_subnets
}

output "workload_availability_zones" {
  description = "Availability Zones that run nodes, NAT gateways, and data services."
  value       = local.workload_availability_zones
}

output "workload_subnet_ids" {
  description = "Private subnets in the workload Availability Zones, used for nodes and the ingress load balancer."
  value       = slice(module.vpc.private_subnets, 0, var.availability_zone_count)
}

output "data_subnet_ids" {
  description = "IDs of the isolated database and cache subnets."
  value       = module.vpc.database_subnets
}
