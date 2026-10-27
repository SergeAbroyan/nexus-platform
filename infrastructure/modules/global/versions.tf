terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.59.0, < 7.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.1.0, < 5.0.0"
    }
  }
}
