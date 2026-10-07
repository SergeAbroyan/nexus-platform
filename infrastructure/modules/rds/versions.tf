terraform {
  required_version = ">= 1.11.1, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.29.0, < 7.0.0"
    }
  }
}
