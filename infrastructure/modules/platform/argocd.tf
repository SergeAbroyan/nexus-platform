locals {
  values = {
    global = {
      domain = "argocd.nexus.local"
    }
    configs = {
      params = {
        "server.insecure" = true
      }
      cm = {
        "admin.enabled"                                          = true
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
      }
      repositories = {
        gitops = {
          name = "gitops"
          type = "git"
          url  = var.gitops.repository
        }
      }
    }
    controller = {
      replicas  = 1
      resources = var.argocd.controller_resources
    }
    server = {
      replicas  = 1
      resources = var.argocd.server_resources
      service = {
        type = "ClusterIP"
      }
    }
    repoServer = {
      replicas  = 1
      resources = var.argocd.repository_server_resources
    }
    applicationSet = {
      replicas = 0
    }
    dex = {
      enabled = false
    }
    notifications = {
      enabled = false
    }
  }
}

ephemeral "aws_secretsmanager_secret_version" "gitops_deploy_key" {
  secret_id = var.gitops.deploy_key_secret_name
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

  set_wo = [{
    name  = "configs.repositories.gitops.sshPrivateKey"
    type  = "string"
    value = ephemeral.aws_secretsmanager_secret_version.gitops_deploy_key.secret_string
  }]
  set_wo_revision = var.gitops.deploy_key_revision
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
    module.alertmanager,
    module.api,
    module.external_secrets,
    module.grafana,
    module.load_balancer_controller,
    module.worker,
  ]
}
