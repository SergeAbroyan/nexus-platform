data "aws_caller_identity" "current" {}

data "aws_subnet" "nodes" {
  for_each = toset(var.node_subnet_ids)

  id = each.key
}

locals {
  disrupted_zone = data.aws_subnet.nodes[var.node_subnet_ids[0]].availability_zone

  fault_injection_policies = toset([
    "AWSFaultInjectionSimulatorEC2Access",
    "AWSFaultInjectionSimulatorEKSAccess",
    "AWSFaultInjectionSimulatorNetworkAccess",
  ])
}

data "aws_iam_policy_document" "fault_injection_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["fis.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "fault_injection" {
  name               = "${var.name}-fault-injection"
  description        = "Role that AWS FIS assumes to run the ${var.name} resilience experiments"
  assume_role_policy = data.aws_iam_policy_document.fault_injection_trust.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "fault_injection" {
  for_each = local.fault_injection_policies

  role       = aws_iam_role.fault_injection.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/${each.key}"
}

resource "aws_fis_experiment_template" "spot_interruption" {
  description = "Send a two-minute Spot interruption notice to one running node of ${var.name}"
  role_arn    = aws_iam_role.fault_injection.arn

  stop_condition {
    source = "none"
  }

  action {
    name      = "interrupt-spot-node"
    action_id = "aws:ec2:send-spot-instance-interruptions"

    parameter {
      key   = "durationBeforeInterruption"
      value = "PT2M"
    }

    target {
      key   = "SpotInstances"
      value = "spot-nodes"
    }
  }

  target {
    name           = "spot-nodes"
    resource_type  = "aws:ec2:spot-instance"
    selection_mode = "COUNT(1)"

    resource_tag {
      key   = "kubernetes.io/cluster/${var.name}"
      value = "owned"
    }

    filter {
      path   = "State.Name"
      values = ["running"]
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-spot-interruption" })
}

resource "aws_fis_experiment_template" "system_node_failure" {
  description = "Terminate half of the managed system nodes of ${var.name}"
  role_arn    = aws_iam_role.fault_injection.arn

  stop_condition {
    source = "none"
  }

  action {
    name      = "terminate-system-nodes"
    action_id = "aws:eks:terminate-nodegroup-instances"

    parameter {
      key   = "instanceTerminationPercentage"
      value = "50"
    }

    target {
      key   = "Nodegroups"
      value = "system-node-group"
    }
  }

  target {
    name           = "system-node-group"
    resource_type  = "aws:eks:nodegroup"
    selection_mode = "ALL"
    resource_arns  = [module.eks.eks_managed_node_groups["system"].node_group_arn]
  }

  tags = merge(var.tags, { Name = "${var.name}-system-node-failure" })
}

resource "aws_fis_experiment_template" "zone_network_disruption" {
  description = "Cut all network traffic of the ${var.name} node subnets in ${local.disrupted_zone} for five minutes"
  role_arn    = aws_iam_role.fault_injection.arn

  stop_condition {
    source = "none"
  }

  action {
    name      = "disrupt-zone"
    action_id = "aws:network:disrupt-connectivity"

    parameter {
      key   = "duration"
      value = "PT5M"
    }

    parameter {
      key   = "scope"
      value = "all"
    }

    target {
      key   = "Subnets"
      value = "zone-subnets"
    }
  }

  target {
    name           = "zone-subnets"
    resource_type  = "aws:ec2:subnet"
    selection_mode = "ALL"
    resource_arns  = [for subnet in data.aws_subnet.nodes : subnet.arn if subnet.availability_zone == local.disrupted_zone]
  }

  tags = merge(var.tags, { Name = "${var.name}-zone-network-disruption" })
}
