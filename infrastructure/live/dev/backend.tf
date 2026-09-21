terraform {
  backend "s3" {
    bucket       = "nexus-terraform-state-123456789012"
    key          = "nexus/dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
