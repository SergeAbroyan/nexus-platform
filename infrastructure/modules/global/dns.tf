module "zone" {
  source  = "terraform-aws-modules/route53/aws"
  version = "6.5.1"

  name          = var.domain_name
  comment       = "Public DNS zone for ${var.name}"
  force_destroy = var.dns_force_destroy

  tags = merge(var.tags, { Name = var.domain_name })
}
