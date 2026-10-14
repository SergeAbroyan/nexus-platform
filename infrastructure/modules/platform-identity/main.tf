locals {
  name                          = "${var.project_name}-${var.environment}"
  load_balancer_controller_name = "${local.name}-aws-load-balancer-controller"
  external_secrets_name         = "${local.name}-external-secrets"
  external_dns_name             = "${local.name}-external-dns"
  alertmanager_name             = "${local.name}-alertmanager"
  grafana_name                  = "${local.name}-grafana"

  standard_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  })
}

module "load_balancer_controller" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.9.0"

  name            = local.load_balancer_controller_name
  use_name_prefix = false
  description     = "Pod Identity role for the Nexus AWS Load Balancer Controller"

  attach_aws_lb_controller_policy = true
  aws_lb_controller_policy_name   = local.load_balancer_controller_name

  associations = {
    controller = {
      cluster_name    = var.cluster_name
      namespace       = var.load_balancer_controller_namespace
      service_account = var.load_balancer_controller_service_account
    }
  }

  tags = local.standard_tags
}

module "external_secrets" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.9.0"

  name            = local.external_secrets_name
  use_name_prefix = false
  description     = "Pod Identity role for the Nexus External Secrets controller"

  attach_custom_policy      = true
  custom_policy_description = "Read-only access to Nexus application and platform secrets"
  policy_statements = [
    {
      sid = "ReadDatabaseSecret"
      actions = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue",
        "secretsmanager:ListSecretVersionIds",
      ]
      resources = concat([var.rds_master_user_secret_arn], var.additional_secret_arns)
    },
    {
      sid       = "DecryptDatabaseSecret"
      actions   = ["kms:Decrypt"]
      resources = concat([var.rds_kms_key_arn], var.additional_secret_kms_key_arns)
    },
  ]

  associations = {
    controller = {
      cluster_name    = var.cluster_name
      namespace       = var.external_secrets_namespace
      service_account = var.external_secrets_service_account
    }
  }

  tags = local.standard_tags
}

module "external_dns" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.9.0"

  name            = local.external_dns_name
  use_name_prefix = false
  description     = "Pod Identity role for the Nexus ExternalDNS controller"

  attach_external_dns_policy    = true
  external_dns_policy_name      = local.external_dns_name
  external_dns_hosted_zone_arns = [var.external_dns_hosted_zone_arn]

  associations = {
    controller = {
      cluster_name    = var.cluster_name
      namespace       = var.external_dns_namespace
      service_account = var.external_dns_service_account
    }
  }

  tags = local.standard_tags
}

module "alertmanager" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.9.0"

  name            = local.alertmanager_name
  use_name_prefix = false
  description     = "Pod Identity role for Nexus Alertmanager"

  attach_custom_policy      = true
  custom_policy_description = "Publish platform alerts to the encrypted SNS topic"
  policy_statements = [
    {
      sid       = "PublishAlerts"
      actions   = ["sns:Publish"]
      resources = [var.alert_sns_topic_arn]
    },
    {
      sid = "EncryptAlertNotifications"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey",
      ]
      resources = [var.alert_sns_kms_key_arn]
    },
  ]

  associations = {
    alertmanager = {
      cluster_name    = var.cluster_name
      namespace       = var.alertmanager_namespace
      service_account = var.alertmanager_service_account
    }
  }

  tags = local.standard_tags
}

module "grafana" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.9.0"

  name            = local.grafana_name
  use_name_prefix = false
  description     = "Pod Identity role for Nexus Grafana"

  attach_custom_policy      = true
  custom_policy_description = "Read CloudWatch metrics, alarms, tags, and logs"
  policy_statements = [
    {
      sid = "ReadCloudWatchMetricsAndAlarms"
      actions = [
        "cloudwatch:DescribeAlarmHistory",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:DescribeAlarmsForMetric",
        "cloudwatch:GetInsightRuleReport",
        "cloudwatch:GetMetricData",
        "cloudwatch:ListMetrics",
      ]
      resources = ["*"]
    },
    {
      sid = "DiscoverAWSResources"
      actions = [
        "ec2:DescribeInstances",
        "ec2:DescribeRegions",
        "ec2:DescribeTags",
        "tag:GetResources",
      ]
      resources = ["*"]
    },
    {
      sid = "ReadCloudWatchLogs"
      actions = [
        "logs:DescribeLogGroups",
        "logs:GetLogEvents",
        "logs:GetLogGroupFields",
        "logs:GetQueryResults",
        "logs:StartQuery",
        "logs:StopQuery",
      ]
      resources = ["*"]
    },
  ]

  associations = {
    grafana = {
      cluster_name    = var.cluster_name
      namespace       = var.grafana_namespace
      service_account = var.grafana_service_account
    }
  }

  tags = local.standard_tags
}
