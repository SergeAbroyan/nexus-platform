locals {
  environment = read_terragrunt_config(find_in_parent_folders("environment.hcl")).locals
  region      = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/network"
}

inputs = {
  vpc              = local.region.vpc
  nat_gateway_mode = local.environment.network.nat_gateway_mode
  flow_logs        = local.environment.network.flow_logs
}
