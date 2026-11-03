data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  application_namespace = "nexus"
  monitoring_namespace  = "monitoring"

  regional_arn_prefix = "arn:${data.aws_partition.current.partition}:%s:${var.region}:${data.aws_caller_identity.current.account_id}"

  service_accounts = {
    load_balancer_controller = { namespace = "kube-system", name = "aws-load-balancer-controller" }
    external_secrets         = { namespace = "external-secrets", name = "external-secrets" }
    kyverno                  = { namespace = "kyverno", name = "kyverno-admission-controller" }
    alertmanager             = { namespace = local.monitoring_namespace, name = "alertmanager" }
    grafana                  = { namespace = local.monitoring_namespace, name = "grafana" }
    api                      = { namespace = local.application_namespace, name = "api" }
    worker                   = { namespace = local.application_namespace, name = "worker" }
  }
}

module "load_balancer_controller" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name            = "${var.name}-aws-load-balancer-controller"
  use_name_prefix = false
  description     = "Pod Identity role for the AWS Load Balancer Controller"

  attach_aws_lb_controller_policy = true
  aws_lb_controller_policy_name   = "${var.name}-aws-load-balancer-controller"

  associations = {
    controller = {
      cluster_name    = var.cluster_name
      namespace       = local.service_accounts.load_balancer_controller.namespace
      service_account = local.service_accounts.load_balancer_controller.name
    }
  }

  tags = var.tags
}

module "external_secrets" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name            = "${var.name}-external-secrets"
  use_name_prefix = false
  description     = "Pod Identity role for the External Secrets controller"

  attach_custom_policy      = true
  custom_policy_description = "Read-only access to Nexus application and platform secrets"
  policy_statements = [
    {
      sid = "ReadSecrets"
      actions = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue",
        "secretsmanager:ListSecretVersionIds",
      ]
      resources = [
        var.database.secret_arn,
        var.grafana_admin_secret_arn,
        "${format(local.regional_arn_prefix, "secretsmanager")}:secret:${var.slack_webhook_secret_name}-??????",
      ]
    },
    {
      sid       = "DecryptSecrets"
      actions   = ["kms:Decrypt"]
      resources = distinct([var.database.secret_kms_key_arn, var.kms_key_arns["secrets"]])
    },
  ]

  associations = {
    controller = {
      cluster_name    = var.cluster_name
      namespace       = local.service_accounts.external_secrets.namespace
      service_account = local.service_accounts.external_secrets.name
    }
  }

  tags = var.tags
}

module "kyverno" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name            = "${var.name}-kyverno"
  use_name_prefix = false
  description     = "Pod Identity role for the Kyverno admission controller"

  attach_custom_policy      = true
  custom_policy_description = "Read Nexus images and their signatures from ECR"
  policy_statements = [
    {
      sid       = "GetEcrAuthorizationToken"
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    },
    {
      sid = "ReadNexusImages"
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:DescribeImages",
        "ecr:GetDownloadUrlForLayer",
        "ecr:ListImages",
      ]
      resources = ["${format(local.regional_arn_prefix, "ecr")}:repository/${var.ecr_namespace}/*"]
    },
  ]

  associations = {
    admission_controller = {
      cluster_name    = var.cluster_name
      namespace       = local.service_accounts.kyverno.namespace
      service_account = local.service_accounts.kyverno.name
    }
  }

  tags = var.tags
}

module "alertmanager" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name            = "${var.name}-alertmanager"
  use_name_prefix = false
  description     = "Pod Identity role for Alertmanager"

  attach_custom_policy      = true
  custom_policy_description = "Publish platform alerts to the encrypted SNS topic"
  policy_statements = [
    {
      sid       = "PublishAlerts"
      actions   = ["sns:Publish"]
      resources = [var.alert_topic_arn]
    },
    {
      sid       = "EncryptAlertNotifications"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
      resources = [var.kms_key_arns["sns"]]
    },
  ]

  associations = {
    alertmanager = {
      cluster_name    = var.cluster_name
      namespace       = local.service_accounts.alertmanager.namespace
      service_account = local.service_accounts.alertmanager.name
    }
  }

  tags = var.tags
}

module "grafana" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name            = "${var.name}-grafana"
  use_name_prefix = false
  description     = "Pod Identity role for Grafana"

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
      namespace       = local.service_accounts.grafana.namespace
      service_account = local.service_accounts.grafana.name
    }
  }

  tags = var.tags
}

module "api" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name            = "${var.name}-api"
  use_name_prefix = false
  description     = "Pod Identity role for the Nexus API"

  attach_custom_policy      = true
  custom_policy_description = "Least-privilege AWS access for the Nexus API"
  policy_statements = [
    {
      sid       = "SendJobs"
      actions   = ["sqs:SendMessage"]
      resources = [var.queue.arn]
    },
    {
      sid       = "EncryptQueueMessages"
      actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
      resources = [var.kms_key_arns["sqs"]]
    },
    {
      sid       = "ConnectToValkey"
      actions   = ["elasticache:Connect"]
      resources = [var.cache.replication_group_arn, var.cache.user_arn]
    },
  ]

  associations = {
    api = {
      cluster_name    = var.cluster_name
      namespace       = local.service_accounts.api.namespace
      service_account = local.service_accounts.api.name
    }
  }

  tags = var.tags
}

module "worker" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name            = "${var.name}-worker"
  use_name_prefix = false
  description     = "Pod Identity role for the Nexus worker"

  attach_custom_policy      = true
  custom_policy_description = "Least-privilege AWS access for the Nexus worker"
  policy_statements = [
    {
      sid = "ConsumeJobs"
      actions = [
        "sqs:ChangeMessageVisibility",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:ReceiveMessage",
      ]
      resources = [var.queue.arn]
    },
    {
      sid       = "DecryptQueueMessages"
      actions   = ["kms:Decrypt"]
      resources = [var.kms_key_arns["sqs"]]
    },
  ]

  associations = {
    worker = {
      cluster_name    = var.cluster_name
      namespace       = local.service_accounts.worker.namespace
      service_account = local.service_accounts.worker.name
    }
  }

  tags = var.tags
}
