locals {
  root_application = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "nexus-bootstrap"
      namespace = var.namespace
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repository
        targetRevision = var.gitops_revision
        path           = var.gitops_chart_path
        helm = {
          valuesObject = {
            platform = {
              clusterName                    = var.cluster_name
              awsRegion                      = var.aws_region
              vpcId                          = var.vpc_id
              karpenterInterruptionQueueName = var.karpenter_interruption_queue_name
              karpenterNodeIamRoleName       = var.karpenter_node_iam_role_name
              ebsKmsKeyArn                   = var.ebs_kms_key_arn
            }
          }
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

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
    extraObjects = [local.root_application]
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = var.chart_repository
  chart            = "argo-cd"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 900

  values = [yamlencode(local.values)]
}
