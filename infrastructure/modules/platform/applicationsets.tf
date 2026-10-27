locals {
  application_name_template        = "{{ .name }}"
  application_namespace_template   = "{{ .namespace }}"
  application_repository_template  = "{{ .repository }}"
  application_revision_template    = "{{ .revision }}"
  application_chart_template       = "{{ .chart }}"
  application_path_template        = "{{ .path }}"
  application_values_template      = "{{ .values }}"
  application_values_file_template = "{{ .valuesFile }}"

  application_sync_policy = {
    automated   = { prune = true, selfHeal = true }
    syncOptions = ["CreateNamespace=true", "ServerSideApply=true"]
    retry = {
      limit   = 10
      backoff = { duration = "30s", factor = 2, maxDuration = "5m" }
    }
  }

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
          extensionProviders = [{
            name = "otel-tracing"
            opentelemetry = {
              service = "otel-traces.monitoring.svc.cluster.local"
              port    = 4317
              resource_detectors = {
                environment = {}
              }
            }
          }]
          defaultConfig = {
            holdApplicationUntilProxyStarts = true
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
      name       = "istio-ingress"
      namespace  = "istio-ingress"
      repository = "https://blob.istio.io/istio-release/charts"
      chart      = "gateway"
      revision   = "1.30.5"
      values = yamlencode({
        name = "istio-ingress"
        service = {
          type = "ClusterIP"
          ports = [
            { name = "http", port = var.ingress_port, targetPort = var.ingress_port, protocol = "TCP" },
          ]
        }
        securityContext = {
          seccompProfile = { type = "RuntimeDefault" }
          sysctls        = [{ name = "net.ipv4.ip_unprivileged_port_start", value = "0" }]
        }
        nodeSelector = { role = "system" }
        topologySpreadConstraints = [{
          maxSkew           = 1
          topologyKey       = "topology.kubernetes.io/zone"
          whenUnsatisfiable = "ScheduleAnyway"
          labelSelector     = { matchLabels = { istio = "ingress" } }
        }]
        autoscaling = {
          enabled     = true
          minReplicas = 2
          maxReplicas = 5
        }
        podDisruptionBudget = { minAvailable = 1 }
        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { cpu = "500m", memory = "512Mi" }
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
        replicas       = var.karpenter.replicas
        serviceAccount = { create = true, name = "karpenter" }
        settings = {
          clusterName       = var.cluster_name
          interruptionQueue = var.karpenter.interruption_queue_name
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
        serviceAccount = { create = true, name = local.service_accounts.external_secrets.name }
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
        region         = var.region
        vpcId          = var.vpc_id
        replicaCount   = 2
        serviceAccount = { create = true, name = local.service_accounts.load_balancer_controller.name }
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
            retention                           = "7d"
            retentionSize                       = "16GB"
            nodeSelector                        = { role = "general" }
            podMonitorSelectorNilUsesHelmValues = false
            podMonitorSelector                  = {}
            podMonitorNamespaceSelector         = {}
            ruleSelectorNilUsesHelmValues       = false
            ruleSelector                        = {}
            ruleNamespaceSelector               = {}
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
          serviceAccount = {
            create = true
            name   = local.service_accounts.alertmanager.name
          }
          config = {
            global = {
              resolve_timeout = "5m"
            }
            route = {
              group_by        = ["namespace", "alertname"]
              group_wait      = "30s"
              group_interval  = "5m"
              repeat_interval = "12h"
              receiver        = "nexus-sns"
              routes = [{
                receiver = "null"
                matchers = ["alertname = Watchdog"]
              }]
            }
            receivers = [
              { name = "null" },
              {
                name = "nexus-sns"
                sns_configs = [{
                  topic_arn     = var.alert_topic_arn
                  send_resolved = true
                  sigv4         = { region = var.region }
                }]
              },
            ]
          }
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
          serviceAccount = {
            create = true
            name   = local.service_accounts.grafana.name
          }
          admin = {
            existingSecret = "grafana-admin"
            userKey        = "admin-user"
            passwordKey    = "admin-password"
          }
          ingress      = { enabled = false }
          nodeSelector = { role = "general" }
          sidecar = {
            dashboards = {
              enabled         = true
              label           = "grafana_dashboard"
              labelValue      = "1"
              searchNamespace = "ALL"
              provider        = { allowUiUpdates = false }
            }
          }
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
          additionalDataSources = [
            {
              name      = "CloudWatch"
              type      = "cloudwatch"
              uid       = "cloudwatch"
              access    = "proxy"
              isDefault = false
              jsonData = {
                authType      = "default"
                defaultRegion = var.region
              }
            },
            {
              name      = "Loki"
              type      = "loki"
              uid       = "loki"
              access    = "proxy"
              url       = "http://loki-gateway.monitoring.svc.cluster.local"
              isDefault = false
              jsonData  = { maxLines = 1000 }
            },
            {
              name      = "Tempo"
              type      = "tempo"
              uid       = "tempo"
              access    = "proxy"
              url       = "http://tempo.monitoring.svc.cluster.local:3200"
              isDefault = false
              jsonData = {
                httpMethod = "GET"
                nodeGraph  = { enabled = true }
                tracesToLogsV2 = {
                  datasourceUid      = "loki"
                  spanStartTimeShift = "-1m"
                  spanEndTimeShift   = "1m"
                  filterByTraceID    = true
                  filterBySpanID     = false
                }
              }
            },
          ]
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
                  region  = var.region
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
                    admin-password = "{{ `{{ .adminPassword }}` }}"
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
    {
      name       = "loki"
      namespace  = "monitoring"
      repository = "ghcr.io/grafana-community/helm-charts"
      chart      = "loki"
      revision   = "18.13.1"
      values = yamlencode({
        deploymentMode = "Monolithic"

        loki = {
          auth_enabled = false
          commonConfig = { replication_factor = 1 }
          storage      = { type = "filesystem" }
          schemaConfig = {
            configs = [{
              from         = "2024-04-01"
              store        = "tsdb"
              object_store = "filesystem"
              schema       = "v13"
              index        = { prefix = "loki_index_", period = "24h" }
            }]
          }
          limits_config = {
            allow_structured_metadata = true
            retention_period          = "168h"
            volume_enabled            = true
          }
          compactor = {
            retention_enabled    = true
            delete_request_store = "filesystem"
          }
        }

        singleBinary = {
          replicas     = 1
          nodeSelector = { role = "general" }
          persistence = {
            enabled      = true
            storageClass = "nexus-gp3"
            size         = "20Gi"
            whenDeleted  = "Retain"
            whenScaled   = "Retain"
          }
          resources = {
            requests = { cpu = "250m", memory = "512Mi" }
            limits   = { cpu = "1", memory = "2Gi" }
          }
        }

        gateway = {
          enabled      = true
          nodeSelector = { role = "general" }
          resources = {
            requests = { cpu = "50m", memory = "64Mi" }
            limits   = { cpu = "250m", memory = "256Mi" }
          }
        }

        chunksCache  = { enabled = false }
        resultsCache = { enabled = false }
        minio        = { enabled = false }
        lokiCanary = {
          enabled = true
          resources = {
            requests = { cpu = "10m", memory = "32Mi" }
            limits   = { cpu = "100m", memory = "128Mi" }
          }
        }
        monitoring = {
          dashboards     = { enabled = true }
          rules          = { enabled = true }
          serviceMonitor = { enabled = true }
        }

        backend = { replicas = 0 }
        read    = { replicas = 0 }
        write   = { replicas = 0 }
      })
    },
    {
      name       = "tempo"
      namespace  = "monitoring"
      repository = "ghcr.io/grafana-community/helm-charts"
      chart      = "tempo"
      revision   = "3.0.0"
      values = yamlencode({
        replicas = 1

        tempo = {
          reportingEnabled = false
          retention        = "168h"
          receivers = {
            otlp = {
              protocols = {
                grpc = { endpoint = "0.0.0.0:4317" }
                http = { endpoint = "0.0.0.0:4318" }
              }
            }
          }
          securityContext = {
            allowPrivilegeEscalation = false
            readOnlyRootFilesystem   = true
            capabilities             = { drop = ["ALL"] }
          }
          resources = {
            requests = { cpu = "250m", memory = "512Mi" }
            limits   = { cpu = "1", memory = "2Gi" }
          }
        }

        securityContext = {
          runAsNonRoot = true
          runAsUser    = 10001
          runAsGroup   = 10001
          fsGroup      = 10001
          seccompProfile = {
            type = "RuntimeDefault"
          }
        }
        serviceAccount = {
          create                       = true
          automountServiceAccountToken = false
        }
        service = { type = "ClusterIP" }
        persistence = {
          enabled                        = true
          enableStatefulSetAutoDeletePVC = false
          storageClassName               = "nexus-gp3"
          accessModes                    = ["ReadWriteOnce"]
          size                           = "20Gi"
        }
        nodeSelector   = { role = "general" }
        serviceMonitor = { enabled = true, interval = "30s" }
        tempoQuery     = { enabled = false }
      })
    },
    {
      name       = "otel-traces"
      namespace  = "monitoring"
      repository = "ghcr.io/open-telemetry/opentelemetry-helm-charts"
      chart      = "opentelemetry-collector"
      revision   = "0.172.0"
      values = yamlencode({
        fullnameOverride = "otel-traces"
        mode             = "deployment"
        replicaCount     = 2

        image = {
          repository = "ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib"
        }
        command = { name = "otelcol-contrib" }

        alternateConfig = {
          extensions = {
            health_check = { endpoint = "$${env:MY_POD_IP}:13133" }
          }
          receivers = {
            otlp = {
              protocols = {
                grpc = { endpoint = "$${env:MY_POD_IP}:4317" }
                http = { endpoint = "$${env:MY_POD_IP}:4318" }
              }
            }
          }
          exporters = {
            "otlp/tempo" = {
              endpoint = "tempo.monitoring.svc.cluster.local:4317"
              tls      = { insecure = true }
              sending_queue = {
                enabled       = true
                num_consumers = 4
                queue_size    = 1000
              }
              retry_on_failure = {
                enabled          = true
                initial_interval = "5s"
                max_interval     = "30s"
                max_elapsed_time = "300s"
              }
            }
          }
          processors = {
            memory_limiter = {
              check_interval         = "5s"
              limit_percentage       = 80
              spike_limit_percentage = 25
            }
            batch = {
              send_batch_size = 1024
              timeout         = "5s"
            }
          }
          service = {
            extensions = ["health_check"]
            pipelines = {
              traces = {
                receivers  = ["otlp"]
                processors = ["memory_limiter", "batch"]
                exporters  = ["otlp/tempo"]
              }
            }
          }
        }

        ports = {
          otlp = {
            enabled       = true
            containerPort = 4317
            servicePort   = 4317
            protocol      = "TCP"
          }
          "otlp-http" = {
            enabled       = true
            containerPort = 4318
            servicePort   = 4318
            protocol      = "TCP"
          }
          "jaeger-compact" = { enabled = false }
          "jaeger-thrift"  = { enabled = false }
          "jaeger-grpc"    = { enabled = false }
          zipkin           = { enabled = false }
          metrics = {
            enabled       = true
            containerPort = 8888
            servicePort   = 8888
            protocol      = "TCP"
          }
        }

        service        = { type = "ClusterIP" }
        serviceAccount = { automountServiceAccountToken = false }
        nodeSelector   = { role = "general" }
        topologySpreadConstraints = [{
          maxSkew           = 1
          topologyKey       = "kubernetes.io/hostname"
          whenUnsatisfiable = "ScheduleAnyway"
          labelSelector = {
            matchLabels = { "app.kubernetes.io/instance" = "otel-traces" }
          }
        }]
        podSecurityContext = {
          runAsNonRoot = true
          runAsUser    = 10001
          runAsGroup   = 10001
          fsGroup      = 10001
          seccompProfile = {
            type = "RuntimeDefault"
          }
        }
        securityContext = {
          allowPrivilegeEscalation = false
          readOnlyRootFilesystem   = true
          capabilities             = { drop = ["ALL"] }
        }
        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { cpu = "500m", memory = "512Mi" }
        }
        podDisruptionBudget = { enabled = true, minAvailable = 1 }
        podMonitor          = { enabled = true }

        extraManifests = [{
          apiVersion = "telemetry.istio.io/v1"
          kind       = "Telemetry"
          metadata = {
            name      = "mesh-default"
            namespace = "istio-system"
          }
          spec = {
            tracing = [{
              providers                = [{ name = "otel-tracing" }]
              randomSamplingPercentage = 1
            }]
          }
        }]
      })
    },
    {
      name       = "otel-logs"
      namespace  = "monitoring"
      repository = "ghcr.io/open-telemetry/opentelemetry-helm-charts"
      chart      = "opentelemetry-collector"
      revision   = "0.172.0"
      values = yamlencode({
        fullnameOverride = "otel-logs"
        mode             = "daemonset"

        image = {
          repository = "ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib"
        }
        command = { name = "otelcol-contrib" }

        presets = {
          logsCollection = {
            enabled              = true
            includeCollectorLogs = false
            storeCheckpoints     = false
          }
          kubernetesAttributes = { enabled = true }
        }

        alternateConfig = {
          extensions = {
            health_check = { endpoint = "$${env:MY_POD_IP}:13133" }
          }
          exporters = {
            "otlphttp/loki" = {
              endpoint = "http://loki-gateway.monitoring.svc.cluster.local/otlp"
              sending_queue = {
                enabled       = true
                num_consumers = 4
                queue_size    = 1000
              }
              retry_on_failure = {
                enabled          = true
                initial_interval = "5s"
                max_interval     = "30s"
                max_elapsed_time = "300s"
              }
            }
          }
          processors = {
            memory_limiter = {
              check_interval         = "5s"
              limit_percentage       = 80
              spike_limit_percentage = 25
            }
            batch = {
              send_batch_size = 1024
              timeout         = "5s"
            }
          }
          service = {
            extensions = ["health_check"]
            pipelines = {
              logs = {
                receivers  = ["filelog"]
                processors = ["memory_limiter", "batch"]
                exporters  = ["otlphttp/loki"]
              }
            }
          }
        }

        ports = {
          otlp             = { enabled = false }
          "otlp-http"      = { enabled = false }
          "jaeger-compact" = { enabled = false }
          "jaeger-thrift"  = { enabled = false }
          "jaeger-grpc"    = { enabled = false }
          zipkin           = { enabled = false }
          metrics = {
            enabled       = true
            containerPort = 8888
            servicePort   = 8888
            protocol      = "TCP"
          }
        }

        tolerations = [{ operator = "Exists" }]
        podSecurityContext = {
          runAsNonRoot = true
          runAsUser    = 10001
          runAsGroup   = 10001
          fsGroup      = 10001
          seccompProfile = {
            type = "RuntimeDefault"
          }
        }
        securityContext = {
          allowPrivilegeEscalation = false
          readOnlyRootFilesystem   = true
          capabilities             = { drop = ["ALL"] }
        }
        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { cpu = "500m", memory = "512Mi" }
        }
        podMonitor = { enabled = true }
      })
    },
  ]

  local_applications = [
    {
      name       = "karpenter-config"
      namespace  = "kube-system"
      path       = "charts/platform/karpenter"
      valuesFile = "karpenter-values.yaml"
      values = yamlencode({
        clusterName  = var.cluster_name
        nodeRoleName = var.karpenter.node_iam_role_name
        ebsKmsKeyArn = var.kms_key_arns["ebs"]
      })
    },
    {
      name       = "storage-config"
      namespace  = "kube-system"
      path       = "charts/platform/storage"
      valuesFile = "storage-values.yaml"
      values     = yamlencode({ kmsKeyArn = var.kms_key_arns["ebs"] })
    },
    {
      name       = "cloudbeaver"
      namespace  = "cloudbeaver"
      path       = "charts/platform/cloudbeaver"
      valuesFile = "cloudbeaver-values.yaml"
      values     = "{}"
    },
    {
      name       = "ingress-config"
      namespace  = "istio-ingress"
      path       = "charts/platform/ingress"
      valuesFile = "ingress-values.yaml"
      values = yamlencode({
        host           = var.application_hostname
        targetGroupArn = module.ingress_load_balancer.target_groups["gateway"].arn
        gateway        = { port = var.ingress_port }
      })
    },
  ]

  nexus_applications = [
    {
      name       = "nexus-runtime"
      path       = "charts/applications/runtime"
      valuesFile = "runtime-values.yaml"
      values     = "{}"
    },
    {
      name       = "nexus-api"
      path       = "charts/applications/api"
      valuesFile = "api-values.yaml"
      values = yamlencode({
        image = { registry = var.ecr_registry }
        config = {
          awsRegion = var.region
          database = {
            host = var.database.host, port = tostring(var.database.port)
            name = var.database.name, user = var.database.username
          }
          valkey = {
            host     = var.cache.host, port = tostring(var.cache.port)
            username = var.cache.username, cacheName = var.cache.replication_group_id
          }
          sqs = { queueURL = var.queue.url }
        }
        externalSecret = {
          enabled         = true
          remoteSecretKey = var.database.secret_arn
          region          = split(":", var.database.secret_arn)[3]
        }
      })
    },
    {
      name       = "nexus-worker"
      path       = "charts/applications/worker"
      valuesFile = "worker-values.yaml"
      values = yamlencode({
        image = { registry = var.ecr_registry }
        config = {
          awsRegion = var.region
          sqs       = { queueURL = var.queue.url }
        }
      })
    },
  ]

  project = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "nexus-platform"
      namespace = var.argocd.namespace
    }
    spec = {
      sourceRepos = [
        var.gitops.repository,
        "https://blob.istio.io/istio-release/charts",
        "public.ecr.aws/karpenter",
        "https://charts.external-secrets.io",
        "https://kubernetes-sigs.github.io/metrics-server",
        "https://aws.github.io/eks-charts",
        "https://prometheus-community.github.io/helm-charts",
        "ghcr.io/grafana-community/helm-charts",
        "ghcr.io/open-telemetry/opentelemetry-helm-charts",
      ]
      destinations = [
        { server = "https://kubernetes.default.svc", namespace = "kube-system" },
        { server = "https://kubernetes.default.svc", namespace = "external-secrets" },
        { server = "https://kubernetes.default.svc", namespace = "istio-system" },
        { server = "https://kubernetes.default.svc", namespace = "istio-ingress" },
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
    metadata   = { name = "nexus-external-platform", namespace = var.argocd.namespace }
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
          syncPolicy = local.application_sync_policy
        }
      }
    }
  }

  local_application_set = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata   = { name = "nexus-local-components", namespace = var.argocd.namespace }
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
          sources = [
            {
              repoURL        = var.gitops.repository
              targetRevision = var.gitops.revision
              path           = local.application_path_template
              helm = {
                releaseName = local.application_name_template
                valueFiles  = ["$values/environments/${var.environment}/${local.application_values_file_template}"]
                values      = local.application_values_template
              }
            },
            {
              repoURL = var.gitops.repository, targetRevision = var.gitops.revision, ref = "values"
            },
          ]
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = local.application_namespace_template
          }
          syncPolicy = local.application_sync_policy
        }
      }
    }
  }

  nexus_application_set = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata   = { name = "nexus-applications", namespace = var.argocd.namespace }
    spec = {
      goTemplate        = true
      goTemplateOptions = ["missingkey=error"]
      generators        = [{ list = { elements = local.nexus_applications } }]
      template = {
        metadata = {
          name       = local.application_name_template
          finalizers = ["resources-finalizer.argocd.argoproj.io"]
        }
        spec = {
          project = "nexus-platform"
          sources = [
            {
              repoURL        = var.gitops.repository
              targetRevision = var.gitops.revision
              path           = local.application_path_template
              helm = {
                releaseName = local.application_name_template
                valueFiles = [
                  "$values/environments/global-values.yaml",
                  "$values/environments/${var.environment}/${local.application_values_file_template}",
                ]
                values = local.application_values_template
              }
            },
            {
              repoURL = var.gitops.repository, targetRevision = var.gitops.revision, ref = "values"
            },
          ]
          destination = { server = "https://kubernetes.default.svc", namespace = "nexus" }
          syncPolicy  = local.application_sync_policy
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
