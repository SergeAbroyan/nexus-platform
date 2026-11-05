locals {
  environment = "staging"

  standby_enabled         = true
  active_region           = "us-east-1"
  availability_zone_count = 3

  application_subdomain = "nexus-staging"
  ingress_port          = 8443

  network = {
    nat_gateway_mode = "one_per_az"

    flow_logs = {
      enabled                  = true
      retention_days           = 14
      max_aggregation_interval = 60
    }
  }

  security = {
    secret_recovery_window_in_days = 7

    kms = {
      key_names               = ["ebs", "eks", "rds", "secrets", "sns", "sqs", "valkey"]
      deletion_window_in_days = 14

      service_principals = {
        sns = ["cloudwatch.amazonaws.com"]
      }
    }
  }

  cluster = {
    kubernetes_version               = "1.36"
    deletion_protection              = false
    control_plane_log_retention_days = 14

    node_group = {
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"
      min_size       = 2
      max_size       = 3
      desired_size   = 2
      disk_size      = 30
    }

    karpenter = {
      namespace                = "kube-system"
      service_account          = "karpenter"
      enable_spot_interruption = true
    }
  }

  data = {
    database = {
      name                  = "nexus"
      master_username       = "nexus_admin"
      engine_version        = "18"
      instance_class        = "db.t4g.small"
      allocated_storage     = 20
      max_allocated_storage = 200
      multi_az              = true
      backup_retention_days = 7
      deletion_protection   = true
      skip_final_snapshot   = false
      apply_immediately     = true
    }

    cache = {
      engine_version          = "9.1"
      node_type               = "cache.t4g.small"
      num_cache_clusters      = 2
      multi_az                = true
      snapshot_retention_days = 3
      log_retention_days      = 14
      apply_immediately       = true
    }

    queue = {
      visibility_timeout_seconds        = 60
      message_retention_seconds         = 345600
      dlq_message_retention_seconds     = 1209600
      receive_wait_time_seconds         = 20
      max_receive_count                 = 5
      kms_data_key_reuse_period_seconds = 300
    }

    backup = {
      schedule       = "cron(0 3 * * ? *)"
      retention_days = 14
      force_destroy  = true
    }

    alarms = {
      period_seconds                       = 60
      evaluation_periods                   = 5
      rds_cpu_threshold_percent            = 80
      rds_free_storage_threshold_bytes     = 5368709120
      valkey_memory_threshold_percent      = 80
      sqs_oldest_message_threshold_seconds = 300
    }
  }

  platform = {
    load_balancer_deletion_protection = false
    backup_bucket_force_destroy       = true

    gitops = {
      revision = "main"
    }

    argocd = {
      namespace        = "argocd"
      chart_repository = "https://argoproj.github.io/argo-helm"
      chart_version    = "10.11.6"
      secrets_revision = 1

      controller_resources = {
        requests = { cpu = "200m", memory = "768Mi" }
        limits   = { cpu = "1", memory = "2Gi" }
      }

      server_resources = {
        requests = { cpu = "50m", memory = "128Mi" }
        limits   = { cpu = "300m", memory = "384Mi" }
      }

      repository_server_resources = {
        requests = { cpu = "100m", memory = "256Mi" }
        limits   = { cpu = "1", memory = "1Gi" }
      }
    }
  }

  edge = {
    price_class                     = "PriceClass_100"
    waf_rate_limit_per_five_minutes = 2000
  }
}
