locals {
  aws_region  = "us-west-2"
  region_code = "usw2"

  vpc = {
    cidr               = "10.40.0.0/16"
    availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]

    public_subnet_cidrs  = ["10.40.0.0/24", "10.40.1.0/24", "10.40.2.0/24"]
    private_subnet_cidrs = ["10.40.16.0/20", "10.40.32.0/20", "10.40.48.0/20"]
    data_subnet_cidrs    = ["10.40.64.0/24", "10.40.65.0/24", "10.40.66.0/24"]
  }
}
