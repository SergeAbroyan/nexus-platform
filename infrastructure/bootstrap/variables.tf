variable "aws_region" {
  description = "AWS region where the bootstrap infrastructure will be created."
  type        = string
  default     = "us-east-1"
}
variable "state_bucket_name" {
  description = "Globally unique S3 bucket name used for Terraform state."
  type        = string
}
