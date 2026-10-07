output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "IPv4 CIDR block assigned to the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of the private application subnets."
  value       = module.vpc.private_subnets
}

output "data_subnet_ids" {
  description = "IDs of the isolated database and cache subnets."
  value       = module.vpc.database_subnets
}
