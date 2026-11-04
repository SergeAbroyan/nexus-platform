locals {
  environment = "production"

  standby_enabled         = true
  active_region           = "us-east-1"
  availability_zone_count = 3

  application_subdomain = "nexus"
  ingress_port          = 8443

  network = {
    nat_gateway_mode = "one_per_az"

    flow_logs = {
      enabled                  = true
      retention_days           = 30
      max_aggregation_interval = 60
    }
  }

  security = {
    secret_recovery_window_in_days = 30

    kms = {
      key_names               = ["ebs", "eks", "rds", "secrets", "sns", "sqs", "valkey"]
      deletion_window_in_days = 30

      service_principals = {
        sns = ["cloudwatch.amazonaws.com"]
      }
    }
  }

  cluster = {
    kubernetes_version               = "1.36"
    admin_user_names                 = ["your-iam-user"]
    public_access_cidrs              = []
    deletion_protection              = true
    control_plane_log_retention_days = 30

    node_group = {
      instance_types = ["m6i.large"]
      capacity_type  = "ON_DEMAND"
      min_size       = 3
      max_size       = 6
      desired_size   = 3
      disk_size      = 50
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
      instance_class        = "db.m7g.large"
      allocated_storage     = 50
      max_allocated_storage = 500
      multi_az              = true
      backup_retention_days = 14
      deletion_protection   = true
      skip_final_snapshot   = false
      apply_immediately     = false
    }

    cache = {
      engine_version          = "9.1"
      node_type               = "cache.m7g.large"
      num_cache_clusters      = 3
      multi_az                = true
      snapshot_retention_days = 7
      log_retention_days      = 30
      apply_immediately       = false
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
      retention_days = 35
      force_destroy  = false
    }

    alarms = {
      period_seconds                       = 60
      evaluation_periods                   = 3
      rds_cpu_threshold_percent            = 75
      rds_free_storage_threshold_bytes     = 10737418240
      valkey_memory_threshold_percent      = 75
      sqs_oldest_message_threshold_seconds = 120
    }
  }

  platform = {
    load_balancer_deletion_protection = true
    backup_bucket_force_destroy       = false

    gitops = {
      revision = "main"
    }

    argocd = {
      namespace        = "argocd"
      chart_repository = "https://argoproj.github.io/argo-helm"
      chart_version    = "10.11.6"
      secrets_revision = 1

      controller_resources = {
        requests = { cpu = "500m", memory = "1Gi" }
        limits   = { cpu = "2", memory = "2Gi" }
      }

      server_resources = {
        requests = { cpu = "100m", memory = "256Mi" }
        limits   = { cpu = "500m", memory = "512Mi" }
      }

      repository_server_resources = {
        requests = { cpu = "200m", memory = "512Mi" }
        limits   = { cpu = "1", memory = "1Gi" }
      }
    }
  }

  edge = {
    price_class                     = "PriceClass_200"
    waf_rate_limit_per_five_minutes = 2000
  }
}
