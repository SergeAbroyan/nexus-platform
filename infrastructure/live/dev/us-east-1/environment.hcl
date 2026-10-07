locals {
  environment = "dev"
  aws_region  = "us-east-1"

  vpc_cidr = "10.10.0.0/16"

  availability_zones = [
    "us-east-1a",
    "us-east-1b",
    "us-east-1c",
  ]

  public_subnet_cidrs = [
    "10.10.0.0/24",
    "10.10.1.0/24",
    "10.10.2.0/24",
  ]

  private_subnet_cidrs = [
    "10.10.16.0/20",
    "10.10.32.0/20",
    "10.10.48.0/20",
  ]

  data_subnet_cidrs = [
    "10.10.64.0/24",
    "10.10.65.0/24",
    "10.10.66.0/24",
  ]

  nat_gateway_mode = "single"

  kms_key_names = [
    "eks",
    "rds",
    "redis",
    "sqs",
  ]

  kms_deletion_window_in_days = 7
}
