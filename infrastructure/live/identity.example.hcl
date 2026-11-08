locals {
  aws_account_id = "123456789012"
  domain_name    = "example.com"

  domain_registered_with_route53 = false

  alert_email_address = "alerts@example.com"

  github_owner    = "your-github-user"
  github_owner_id = "12345678"

  administrators = {
    iam_user_names = ["your-iam-user"]
    github_logins  = ["your-github-user"]
    cidrs          = ["203.0.113.10/32"]
  }

  argocd_github_client_id = ""

  cloudflare = {
    account_id        = ""
    access_team       = ""
    access_emails     = ["you@example.com"]
    dns_authoritative = false
    keep_route53_zone = false
  }
}
