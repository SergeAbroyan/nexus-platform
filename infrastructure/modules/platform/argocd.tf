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

module "argocd" {
  source  = "terraform-module/release/helm"
  version = "2.9.1"

  namespace  = var.argocd.namespace
  repository = var.argocd.chart_repository

  app = {
    name             = "argocd"
    chart            = "argo-cd"
    version          = var.argocd.chart_version
    deploy           = true
    create_namespace = true
    atomic           = true
    cleanup_on_fail  = true
    wait             = true
    recreate_pods    = false
    lint             = false
    timeout          = 900
  }

  values = [yamlencode(local.values)]
}

module "gitops_bootstrap" {
  source  = "terraform-module/release/helm"
  version = "2.9.1"

  namespace  = var.argocd.namespace
  repository = null

  app = {
    name             = "argocd-gitops"
    chart            = "${path.module}/charts/gitops"
    version          = "0.1.0"
    deploy           = true
    create_namespace = false
    atomic           = true
    cleanup_on_fail  = true
    wait             = true
    recreate_pods    = false
    lint             = false
    timeout          = 300
  }

  values = [yamlencode({ objects = [local.bootstrap_project, local.bootstrap_application] })]

  depends_on = [
    module.argocd,
    module.alertmanager,
    module.api,
    module.external_secrets,
    module.grafana,
    module.load_balancer_controller,
    module.worker,
  ]
}
