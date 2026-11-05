locals {
  github_sso               = var.github_sso.enabled
  github_oauth_secret_name = "argocd-github-oauth"
  gitops_repository_secret = "argocd-repository-gitops"

  sso_config = local.github_sso ? {
    url = "http://localhost:8080"
    "dex.config" = yamlencode({
      connectors = [{
        type = "github"
        id   = "github"
        name = "GitHub"
        config = {
          clientID     = var.github_sso.client_id
          clientSecret = format("$%s:clientSecret", local.github_oauth_secret_name)
        }
      }]
    })
  } : {}

  values = {
    global = {
      domain = "argocd.nexus.local"
    }
    configs = {
      params = {
        "server.insecure" = true
      }
      cm = merge(local.sso_config, {
        "admin.enabled"                                          = !local.github_sso
        "application.resourceTrackingMethod"                     = "annotation"
        "resource.customizations.health.argoproj.io_Application" = <<-EOT
          hs = { status = "Progressing", message = "" }
          if obj.status ~= nil and obj.status.health ~= nil then
            hs.status = obj.status.health.status
            if obj.status.health.message ~= nil then
              hs.message = obj.status.health.message
            end
          end
          return hs
        EOT
      })
      rbac = local.github_sso ? {
        "policy.default" = ""
        "policy.csv"     = join("\n", [for login in var.github_sso.admin_logins : "g, ${login}, role:admin"])
        scopes           = "[preferred_username]"
      } : {}
    }
    controller = {
      replicas  = 1
      resources = var.argocd.controller_resources
      metrics   = { enabled = true }
    }
    server = {
      replicas  = 1
      resources = var.argocd.server_resources
      metrics   = { enabled = true }
      service = {
        type = "ClusterIP"
      }
    }
    repoServer = {
      replicas  = 1
      resources = var.argocd.repository_server_resources
      metrics   = { enabled = true }
    }
    applicationSet = {
      replicas = 0
    }
    dex = {
      enabled = local.github_sso
    }
    notifications = {
      enabled = false
    }
  }
}

ephemeral "aws_secretsmanager_secret_version" "gitops_deploy_key" {
  secret_id = var.gitops.deploy_key_secret_name
}

ephemeral "aws_secretsmanager_secret_version" "github_oauth_client_secret" {
  count = local.github_sso ? 1 : 0

  secret_id = var.github_sso.client_secret_name
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.argocd.namespace
  create_namespace = true
  repository       = var.argocd.chart_repository
  chart            = "argo-cd"
  version          = var.argocd.chart_version

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 900
  max_history     = 10

  values = [yamlencode(local.values)]
}

resource "kubernetes_secret_v1" "gitops_repository" {
  metadata {
    name      = local.gitops_repository_secret
    namespace = var.argocd.namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data_wo = {
    name          = "gitops"
    type          = "git"
    url           = var.gitops.repository
    sshPrivateKey = ephemeral.aws_secretsmanager_secret_version.gitops_deploy_key.secret_string
  }
  data_wo_revision = var.argocd.secrets_revision

  depends_on = [helm_release.argocd]
}

resource "kubernetes_secret_v1" "github_oauth" {
  count = local.github_sso ? 1 : 0

  metadata {
    name      = local.github_oauth_secret_name
    namespace = var.argocd.namespace
    labels = {
      "app.kubernetes.io/part-of" = "argocd"
    }
  }

  data_wo = {
    clientSecret = ephemeral.aws_secretsmanager_secret_version.github_oauth_client_secret[0].secret_string
  }
  data_wo_revision = var.argocd.secrets_revision

  depends_on = [helm_release.argocd]
}

resource "helm_release" "gitops_bootstrap" {
  name      = "argocd-gitops"
  namespace = var.argocd.namespace
  chart     = "${path.module}/charts/gitops"

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 300
  max_history     = 10

  values = [yamlencode({ objects = [local.bootstrap_project, local.bootstrap_application] })]

  depends_on = [
    helm_release.argocd,
    kubernetes_secret_v1.gitops_repository,
    module.alertmanager,
    module.api,
    module.external_secrets,
    module.grafana,
    module.keda,
    module.kyverno,
    module.load_balancer_controller,
    module.trivy_operator,
    module.velero,
    module.worker,
  ]
}
