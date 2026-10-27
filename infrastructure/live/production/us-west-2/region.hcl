locals {
  aws_region  = "us-west-2"
  region_code = "usw2"

  vpc = {
    cidr               = "10.60.0.0/16"
    availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

    public_subnet_cidrs  = ["10.60.0.0/24", "10.60.1.0/24", "10.60.2.0/24"]
    private_subnet_cidrs = ["10.60.16.0/20", "10.60.32.0/20", "10.60.48.0/20"]
    data_subnet_cidrs    = ["10.60.64.0/24", "10.60.65.0/24", "10.60.66.0/24"]
  }
}
