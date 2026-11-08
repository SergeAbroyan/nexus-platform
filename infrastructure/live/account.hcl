locals {
  identity = read_terragrunt_config("${get_terragrunt_dir()}/identity.hcl").locals

  project_name   = "nexus"
  aws_account_id = local.identity.aws_account_id

  primary_region = "us-east-1"
  standby_region = "us-west-2"

  domain_name                    = local.identity.domain_name
  domain_registered_with_route53 = local.identity.domain_registered_with_route53
  alert_email_address            = local.identity.alert_email_address
  administrators                 = local.identity.administrators

  environments = ["dev", "staging", "production"]

  github = {
    owner                     = local.identity.github_owner
    owner_id                  = local.identity.github_owner_id
    infrastructure_repository = "nexus-platform"
    applications_repository   = "nexus-applications"
    gitops_repository         = "nexus-gitops"
    deployment_branch         = "main"
  }

  cloudflare = local.identity.cloudflare.account_id == "" ? null : local.identity.cloudflare

  admin_access = {
    environments     = ["dev"]
    session_duration = "24h"

    tools = {
      argocd       = "http://argocd-server.argocd.svc.cluster.local:80"
      grafana      = "http://monitoring-grafana.monitoring.svc.cluster.local:80"
      prometheus   = "http://monitoring-prometheus.monitoring.svc.cluster.local:9090"
      alertmanager = "http://monitoring-alertmanager.monitoring.svc.cluster.local:9093"
      goldilocks   = "http://goldilocks-dashboard.goldilocks.svc.cluster.local:80"
      policies     = "http://policy-reporter-ui.policy-reporter.svc.cluster.local:8080"
      opencost     = "http://opencost.opencost.svc.cluster.local:9090"
      cloudbeaver  = "http://cloudbeaver.cloudbeaver.svc.cluster.local:8978"
      pyroscope    = "http://pyroscope.monitoring.svc.cluster.local:4040"
    }
  }

  argocd_github_sso = {
    enabled      = local.identity.argocd_github_client_id != ""
    client_id    = local.identity.argocd_github_client_id
    admin_logins = local.identity.administrators.github_logins
  }

  guardduty_enabled    = false
  security_hub_enabled = false

  audit = {
    retention_days = 365
    force_destroy  = true
  }

  dns_force_destroy         = true
  monthly_budget_amount_usd = 100

  ecr = {
    repository_names    = ["api", "worker"]
    force_delete        = true
    maximum_image_count = 300
  }
}
