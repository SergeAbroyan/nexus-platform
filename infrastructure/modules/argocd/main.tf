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
      resources = var.controller_resources
    }
    server = {
      replicas  = 1
      resources = var.server_resources
      service = {
        type = "ClusterIP"
      }
    }
    repoServer = {
      replicas  = 1
      resources = var.repository_server_resources
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
    extraObjects = local.gitops_objects
  }
}

module "argocd" {
  source  = "terraform-module/release/helm"
  version = "2.9.1"

  namespace  = var.namespace
  repository = var.chart_repository

  app = {
    name             = "argocd"
    chart            = "argo-cd"
    version          = var.chart_version
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
