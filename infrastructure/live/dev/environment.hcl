locals {
  environment = "dev"

  standby_enabled         = false
  active_region           = "us-east-1"
  availability_zone_count = 1

  application_subdomain = "nexus-dev"
  ingress_port          = 8443

  network = {
    nat_gateway_mode = "single"

    flow_logs = {
      enabled                  = true
      retention_days           = 7
      max_aggregation_interval = 60
    }
  }

  security = {
    secret_recovery_window_in_days = 0

    kms = {
      key_names               = ["ebs", "eks", "rds", "secrets", "sns", "sqs", "valkey"]
      deletion_window_in_days = 7

      service_principals = {
        sns = ["cloudwatch.amazonaws.com"]
      }
    }
  }

  cluster = {
    kubernetes_version               = "1.36"
    deletion_protection              = false
    control_plane_log_types          = ["api", "authenticator", "controllerManager", "scheduler"]
    control_plane_log_retention_days = 7

    node_group = {
      instance_types = ["t3.large", "t3a.large", "m5.large", "m5a.large", "m6i.large", "m6a.large", "m7i.large"]
      capacity_type  = "SPOT"
      min_size       = 1
      max_size       = 2
      desired_size   = 1
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
      instance_class        = "db.t4g.micro"
      allocated_storage     = 20
      max_allocated_storage = 100
      multi_az              = false
      backup_retention_days = 7
      deletion_protection   = false
      skip_final_snapshot   = true
      apply_immediately     = true
    }

    cache = {
      engine_version          = "9.1"
      node_type               = "cache.t4g.micro"
      num_cache_clusters      = 1
      multi_az                = false
      snapshot_retention_days = 1
      log_retention_days      = 7
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
      retention_days = 7
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
        requests = { cpu = "200m", memory = "512Mi" }
        limits   = { cpu = "1", memory = "1536Mi" }
      }

      server_resources = {
        requests = { cpu = "50m", memory = "128Mi" }
        limits   = { cpu = "200m", memory = "256Mi" }
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
