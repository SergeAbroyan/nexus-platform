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
        "admin.enabled"                      = true
        "application.resourceTrackingMethod" = "annotation"
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
      replicas = 1
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

  values = [yamlencode({ objects = local.gitops_objects })]

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
