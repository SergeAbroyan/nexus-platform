locals {
  aws_region  = "us-east-1"
  region_code = "use1"

  vpc = {
    cidr               = "10.10.0.0/16"
    availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

    public_subnet_cidrs  = ["10.10.0.0/24", "10.10.1.0/24", "10.10.2.0/24"]
    private_subnet_cidrs = ["10.10.16.0/20", "10.10.32.0/20", "10.10.48.0/20"]
    data_subnet_cidrs    = ["10.10.64.0/24", "10.10.65.0/24", "10.10.66.0/24"]
  }
}
