module "gitops_deploy_key" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "2.2.0"

  name                    = "${var.name}/argocd/gitops-deploy-key"
  description             = "Read-only SSH deploy key that Argo CD uses to fetch ${var.github.owner}/${var.github.gitops_repository}"
  recovery_window_in_days = 7
  replica                 = { (var.standby_region) = {} }

  secret_string         = "Replace this value with the private key of the read-only GitHub deploy key."
  ignore_secret_changes = true

  tags = merge(var.tags, { Name = "${var.name}-argocd-gitops-deploy-key" })
}
