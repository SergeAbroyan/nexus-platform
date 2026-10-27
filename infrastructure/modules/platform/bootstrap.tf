locals {
  cluster_facts = {
    environment = var.environment
    name        = var.cluster_name
    region      = var.region
    vpcId       = var.vpc_id
    hostname    = var.application_hostname

    gitops = {
      repository = var.gitops.repository
      revision   = var.gitops.revision
    }

    ingress = {
      port           = var.ingress_port
      targetGroupArn = module.ingress_load_balancer.target_groups["gateway"].arn
    }

    ecrRegistry  = var.ecr_registry
    ebsKmsKeyArn = var.kms_key_arns["ebs"]

    karpenter = {
      nodeRoleName      = var.karpenter.node_iam_role_name
      interruptionQueue = var.karpenter.interruption_queue_name
    }

    serviceAccounts = {
      karpenter              = var.karpenter.service_account
      loadBalancerController = local.service_accounts.load_balancer_controller
      externalSecrets        = local.service_accounts.external_secrets
      alertmanager           = local.service_accounts.alertmanager
      grafana                = local.service_accounts.grafana
      api                    = local.service_accounts.api
      worker                 = local.service_accounts.worker
    }

    alertTopicArn         = var.alert_topic_arn
    grafanaAdminSecretArn = var.grafana_admin_secret_arn

    database = {
      host      = var.database.host
      port      = var.database.port
      name      = var.database.name
      username  = var.database.username
      secretArn = var.database.secret_arn
    }

    cache = {
      host               = var.cache.host
      port               = var.cache.port
      username           = var.cache.username
      replicationGroupId = var.cache.replication_group_id
    }

    queue = {
      url                      = var.queue.url
      receiveWaitTimeSeconds   = var.queue.receive_wait_time_seconds
      visibilityTimeoutSeconds = var.queue.visibility_timeout_seconds
    }
  }

  bootstrap_project = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "bootstrap"
      namespace = var.argocd.namespace
    }
    spec = {
      sourceRepos  = [var.gitops.repository]
      destinations = [{ server = "https://kubernetes.default.svc", namespace = var.argocd.namespace }]
      namespaceResourceWhitelist = [
        { group = "argoproj.io", kind = "AppProject" },
        { group = "argoproj.io", kind = "Application" },
      ]
    }
  }

  bootstrap_application = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "bootstrap"
      namespace  = var.argocd.namespace
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = local.bootstrap_project.metadata.name
      sources = [
        {
          repoURL        = var.gitops.repository
          targetRevision = var.gitops.revision
          path           = "bootstrap"
          helm = {
            releaseName             = "bootstrap"
            valueFiles              = ["$values/environments/${var.environment}/bootstrap-values.yaml"]
            ignoreMissingValueFiles = true
            valuesObject            = { cluster = local.cluster_facts }
          }
        },
        {
          repoURL        = var.gitops.repository
          targetRevision = var.gitops.revision
          ref            = "values"
        },
      ]
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.argocd.namespace
      }
      syncPolicy = {
        automated = { prune = true, selfHeal = true }
        retry = {
          limit   = 10
          backoff = { duration = "30s", factor = 2, maxDuration = "5m" }
        }
      }
    }
  }
}
