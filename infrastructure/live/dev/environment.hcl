locals {
  project_name   = "nexus"
  environment    = "dev"
  aws_account_id = "123456789012"

  primary_region = "us-east-1"
  standby_region = "us-west-2"
  active_region  = "us-east-1"

  domain_name           = ""
  application_subdomain = "nexus"
  alert_email_address   = "alerts@example.com"
  ingress_port          = 8443

  github = {
    owner                      = "SergeAbroyan"
    infrastructure_repository  = "nexus-platform"
    applications_repository    = "nexus-applications"
    deployment_branch          = "main"
    infrastructure_environment = "dev"
  }

  global = {
    dns_force_destroy         = true
    monthly_budget_amount_usd = 200

    ecr = {
      repository_names              = ["api", "worker"]
      force_delete                  = true
      untagged_image_retention_days = 7
      maximum_image_count           = 20
    }
  }

  network = {
    nat_gateway_mode = "one_per_az"

    flow_logs = {
      enabled                  = true
      retention_days           = 7
      max_aggregation_interval = 60
    }
  }

  security = {
    secret_recovery_window_in_days = 7

    kms = {
      key_names               = ["ebs", "eks", "rds", "secrets", "sns", "sqs", "valkey"]
      deletion_window_in_days = 7

      service_principals = {
        sns = ["cloudwatch.amazonaws.com"]
      }
    }
  }

  cluster = {
    kubernetes_version               = "1.35"
    admin_user_names                 = ["your-iam-user"]
    public_access_cidrs              = []
    deletion_protection              = false
    control_plane_log_retention_days = 7

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
      engine_version        = "17"
      instance_class        = "db.t4g.micro"
      allocated_storage     = 20
      max_allocated_storage = 100
      multi_az              = true
      backup_retention_days = 7
      deletion_protection   = false
      skip_final_snapshot   = true
      apply_immediately     = true
    }

    cache = {
      engine_version          = "8.1"
      node_type               = "cache.t4g.micro"
      num_cache_clusters      = 2
      multi_az                = true
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
    karpenter_replicas                = 2
    load_balancer_deletion_protection = false

    gitops = {
      repository = "https://github.com/SergeAbroyan/nexus-gitops.git"
      revision   = "main"
    }

    argocd = {
      namespace        = "argocd"
      chart_repository = "https://argoproj.github.io/argo-helm"
      chart_version    = "10.9.6"

      controller_resources = {
        requests = { cpu = "100m", memory = "256Mi" }
        limits   = { cpu = "500m", memory = "512Mi" }
      }

      server_resources = {
        requests = { cpu = "50m", memory = "128Mi" }
        limits   = { cpu = "200m", memory = "256Mi" }
      }

      repository_server_resources = {
        requests = { cpu = "50m", memory = "128Mi" }
        limits   = { cpu = "300m", memory = "256Mi" }
      }
    }
  }

  edge = {
    price_class                     = "PriceClass_100"
    waf_rate_limit_per_five_minutes = 2000
  }
}
