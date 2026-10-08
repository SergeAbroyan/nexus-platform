locals {
  application_name_template       = "{{ `{{ .name }}` }}"
  application_namespace_template  = "{{ `{{ .namespace }}` }}"
  application_repository_template = "{{ `{{ .repository }}` }}"
  application_revision_template   = "{{ `{{ .revision }}` }}"
  application_chart_template      = "{{ `{{ .chart }}` }}"
  application_path_template       = "{{ `{{ .path }}` }}"
  application_values_template     = "{{ `{{ .values }}` }}"

  external_applications = [
    {
      name       = "istio-base"
      namespace  = "istio-system"
      repository = "https://blob.istio.io/istio-release/charts"
      chart      = "base"
      revision   = "1.30.5"
      values     = yamlencode({ defaultRevision = "default" })
    },
    {
      name       = "istio-cni"
      namespace  = "istio-system"
      repository = "https://blob.istio.io/istio-release/charts"
      chart      = "cni"
      revision   = "1.30.5"
      values = yamlencode({
        cni = {
          excludeNamespaces = ["kube-system", "istio-system"]
          resources = {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { cpu = "200m", memory = "256Mi" }
          }
        }
      })
    },
    {
      name       = "istiod"
      namespace  = "istio-system"
      repository = "https://blob.istio.io/istio-release/charts"
      chart      = "istiod"
      revision   = "1.30.5"
      values = yamlencode({
        pilot = {
          cni          = { enabled = true }
          nodeSelector = { role = "system" }
          resources = {
            requests = { cpu = "100m", memory = "256Mi" }
            limits   = { cpu = "500m", memory = "512Mi" }
          }
        }
        meshConfig = {
          enablePrometheusMerge = true
          enableTracing         = true
          defaultConfig = {
            holdApplicationUntilProxyStarts = true
            tracing                         = { sampling = 1 }
          }
          outboundTrafficPolicy = { mode = "ALLOW_ANY" }
        }
        global = {
          proxy = {
            resources = {
              requests = { cpu = "50m", memory = "64Mi" }
              limits   = { cpu = "500m", memory = "256Mi" }
            }
          }
        }
      })
    },
    {
      name       = "karpenter-crd"
      namespace  = "kube-system"
      repository = "public.ecr.aws/karpenter"
      chart      = "karpenter-crd"
      revision   = "1.14.1"
      values     = "{}"
    },
    {
      name       = "karpenter"
      namespace  = "kube-system"
      repository = "public.ecr.aws/karpenter"
      chart      = "karpenter"
      revision   = "1.14.1"
      values = yamlencode({
        serviceAccount = { create = true, name = "karpenter" }
        settings = {
          clusterName       = var.cluster_name
          interruptionQueue = var.karpenter_interruption_queue_name
        }
        nodeSelector = { role = "system" }
        controller = {
          resources = {
            requests = { cpu = "250m", memory = "512Mi" }
            limits   = { cpu = "1", memory = "1Gi" }
          }
        }
      })
    },
    {
      name       = "external-secrets"
      namespace  = "external-secrets"
      repository = "https://charts.external-secrets.io"
      chart      = "external-secrets"
      revision   = "2.11.0"
      values = yamlencode({
        installCRDs    = true
        serviceAccount = { create = true, name = "external-secrets" }
        nodeSelector   = { role = "system" }
        resources = {
          requests = { cpu = "50m", memory = "128Mi" }
          limits   = { cpu = "300m", memory = "256Mi" }
        }
      })
    },
    {
      name       = "metrics-server"
      namespace  = "kube-system"
      repository = "https://kubernetes-sigs.github.io/metrics-server"
      chart      = "metrics-server"
      revision   = "3.13.1"
      values = yamlencode({
        replicas     = 1
        nodeSelector = { role = "system" }
        resources = {
          requests = { cpu = "50m", memory = "100Mi" }
          limits   = { cpu = "200m", memory = "256Mi" }
        }
      })
    },
    {
      name       = "aws-load-balancer-controller"
      namespace  = "kube-system"
      repository = "https://aws.github.io/eks-charts"
      chart      = "aws-load-balancer-controller"
      revision   = "3.4.3"
      values = yamlencode({
        clusterName    = var.cluster_name
        region         = var.aws_region
        vpcId          = var.vpc_id
        replicaCount   = 2
        serviceAccount = { create = true, name = "aws-load-balancer-controller" }
        nodeSelector   = { role = "system" }
        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { cpu = "500m", memory = "256Mi" }
        }
      })
    },
    {
      name       = "monitoring"
      namespace  = "monitoring"
      repository = "https://prometheus-community.github.io/helm-charts"
      chart      = "kube-prometheus-stack"
      revision   = "92.1.0"
      values = yamlencode({
        fullnameOverride      = "monitoring"
        kubeEtcd              = { enabled = false }
        kubeControllerManager = { enabled = false }
        kubeScheduler         = { enabled = false }

        prometheusOperator = {
          nodeSelector = { role = "system" }
          resources = {
            requests = { cpu = "100m", memory = "256Mi" }
            limits   = { cpu = "500m", memory = "512Mi" }
          }
        }

        prometheus = {
          prometheusSpec = {
            retention     = "7d"
            retentionSize = "16GB"
            nodeSelector  = { role = "general" }
            resources = {
              requests = { cpu = "500m", memory = "1Gi" }
              limits   = { cpu = "2", memory = "3Gi" }
            }
            storageSpec = {
              volumeClaimTemplate = {
                spec = {
                  storageClassName = "nexus-gp3"
                  accessModes      = ["ReadWriteOnce"]
                  resources        = { requests = { storage = "20Gi" } }
                }
              }
            }
          }
        }

        alertmanager = {
          alertmanagerSpec = {
            nodeSelector = { role = "general" }
            resources = {
              requests = { cpu = "100m", memory = "128Mi" }
              limits   = { cpu = "500m", memory = "512Mi" }
            }
            storage = {
              volumeClaimTemplate = {
                spec = {
                  storageClassName = "nexus-gp3"
                  accessModes      = ["ReadWriteOnce"]
                  resources        = { requests = { storage = "5Gi" } }
                }
              }
            }
          }
        }

        grafana = {
          admin = {
            existingSecret = "grafana-admin"
            userKey        = "admin-user"
            passwordKey    = "admin-password"
          }
          ingress      = { enabled = false }
          nodeSelector = { role = "general" }
          persistence = {
            enabled          = true
            type             = "sts"
            storageClassName = "nexus-gp3"
            accessModes      = ["ReadWriteOnce"]
            size             = "5Gi"
          }
          resources = {
            requests = { cpu = "100m", memory = "256Mi" }
            limits   = { cpu = "500m", memory = "1Gi" }
          }
        }

        extraManifests = [
          {
            apiVersion = "external-secrets.io/v1"
            kind       = "SecretStore"
            metadata   = { name = "aws-secrets-manager" }
            spec = {
              provider = {
                aws = {
                  service = "SecretsManager"
                  region  = var.aws_region
                }
              }
            }
          },
          {
            apiVersion = "external-secrets.io/v1"
            kind       = "ExternalSecret"
            metadata   = { name = "grafana-admin" }
            spec = {
              refreshInterval = "1h"
              secretStoreRef = {
                name = "aws-secrets-manager"
                kind = "SecretStore"
              }
              target = {
                name           = "grafana-admin"
                creationPolicy = "Owner"
                template = {
                  type = "Opaque"
                  data = {
                    admin-user     = "admin"
                    admin-password = "{{ printf \"{{ `%s` }}\" \"{{ .adminPassword }}\" }}"
                  }
                }
              }
              data = [{
                secretKey = "adminPassword"
                remoteRef = { key = var.grafana_admin_secret_arn }
              }]
            }
          },
        ]
      })
    },
  ]

  local_applications = [
    {
      name      = "karpenter-config"
      namespace = "kube-system"
      path      = "charts/platform/karpenter"
      values = yamlencode({
        clusterName  = var.cluster_name
        nodeRoleName = var.karpenter_node_iam_role_name
        ebsKmsKeyArn = var.ebs_kms_key_arn
      })
    },
    {
      name      = "storage-config"
      namespace = "kube-system"
      path      = "charts/platform/storage"
      values    = yamlencode({ kmsKeyArn = var.ebs_kms_key_arn })
    },
    {
      name      = "cloudbeaver"
      namespace = "cloudbeaver"
      path      = "charts/tools/cloudbeaver"
      values    = "{}"
    },
  ]

  project = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "nexus-platform"
      namespace = var.namespace
    }
    spec = {
      sourceRepos = [
        var.gitops_repository,
        "https://blob.istio.io/istio-release/charts",
        "public.ecr.aws/karpenter",
        "https://charts.external-secrets.io",
        "https://kubernetes-sigs.github.io/metrics-server",
        "https://aws.github.io/eks-charts",
        "https://prometheus-community.github.io/helm-charts",
      ]
      destinations = [
        { server = "https://kubernetes.default.svc", namespace = "kube-system" },
        { server = "https://kubernetes.default.svc", namespace = "external-secrets" },
        { server = "https://kubernetes.default.svc", namespace = "istio-system" },
        { server = "https://kubernetes.default.svc", namespace = "cloudbeaver" },
        { server = "https://kubernetes.default.svc", namespace = "nexus" },
        { server = "https://kubernetes.default.svc", namespace = "monitoring" },
      ]
      clusterResourceWhitelist   = [{ group = "*", kind = "*" }]
      namespaceResourceWhitelist = [{ group = "*", kind = "*" }]
    }
  }

  external_application_set = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata   = { name = "nexus-external-platform", namespace = var.namespace }
    spec = {
      goTemplate        = true
      goTemplateOptions = ["missingkey=error"]
      generators        = [{ list = { elements = local.external_applications } }]
      template = {
        metadata = {
          name       = local.application_name_template
          finalizers = ["resources-finalizer.argocd.argoproj.io"]
        }
        spec = {
          project = "nexus-platform"
          source = {
            repoURL        = local.application_repository_template
            chart          = local.application_chart_template
            targetRevision = local.application_revision_template
            helm = {
              releaseName = local.application_name_template
              values      = local.application_values_template
            }
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = local.application_namespace_template
          }
          syncPolicy = {
            automated   = { prune = true, selfHeal = true }
            syncOptions = ["CreateNamespace=true", "ServerSideApply=true"]
          }
        }
      }
    }
  }

  local_application_set = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata   = { name = "nexus-local-components", namespace = var.namespace }
    spec = {
      goTemplate        = true
      goTemplateOptions = ["missingkey=error"]
      generators        = [{ list = { elements = local.local_applications } }]
      template = {
        metadata = {
          name       = local.application_name_template
          finalizers = ["resources-finalizer.argocd.argoproj.io"]
        }
        spec = {
          project = "nexus-platform"
          source = {
            repoURL        = var.gitops_repository
            targetRevision = var.gitops_revision
            path           = local.application_path_template
            helm = {
              releaseName = local.application_name_template
              values      = local.application_values_template
            }
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = local.application_namespace_template
          }
          syncPolicy = {
            automated   = { prune = true, selfHeal = true }
            syncOptions = ["CreateNamespace=true", "ServerSideApply=true"]
          }
        }
      }
    }
  }

  nexus_application_set = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata   = { name = "nexus-applications", namespace = var.namespace }
    spec = {
      generators = [{ list = { elements = [{ environment = var.environment }] } }]
      template = {
        metadata = {
          name       = "nexus-${var.environment}"
          finalizers = ["resources-finalizer.argocd.argoproj.io"]
        }
        spec = {
          project = "nexus-platform"
          sources = [
            {
              repoURL        = var.gitops_repository
              targetRevision = var.gitops_revision
              path           = "charts/applications/nexus"
              helm = {
                releaseName = "nexus"
                valueFiles  = ["$values/environments/${var.environment}/values.yaml"]
                values = yamlencode({
                  image = { registry = var.ecr_registry_url }
                  config = {
                    awsRegion = var.aws_region
                    database = {
                      host = var.database_host, port = tostring(var.database_port)
                      name = var.database_name, user = var.database_username
                    }
                    valkey = {
                      host     = var.valkey_host, port = tostring(var.valkey_port)
                      username = var.valkey_username, cacheName = var.valkey_cache_name
                    }
                    sqs = { queueURL = var.sqs_queue_url }
                  }
                  externalSecret = { enabled = true, remoteSecretKey = var.database_secret_arn }
                })
              }
            },
            {
              repoURL = var.gitops_repository, targetRevision = var.gitops_revision, ref = "values"
            },
          ]
          destination = { server = "https://kubernetes.default.svc", namespace = "nexus" }
          syncPolicy = {
            automated   = { prune = true, selfHeal = true }
            syncOptions = ["CreateNamespace=true", "ServerSideApply=true"]
          }
        }
      }
    }
  }

  gitops_objects = [
    local.project,
    local.external_application_set,
    local.local_application_set,
    local.nexus_application_set,
  ]
}
