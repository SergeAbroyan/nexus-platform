locals {
  budget_name = "${var.project_name}-${var.environment}-monthly-cost"

  standard_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  })
}

module "budget" {
  source  = "appvia/budgets/aws"
  version = "4.0.0"

  budgets = [
    {
      name         = local.budget_name
      budget_type  = "COST"
      limit_amount = tostring(var.monthly_limit_usd)
      limit_unit   = "USD"
      time_unit    = "MONTHLY"

      notifications = {
        actual_50_percent = {
          comparison_operator = "GREATER_THAN"
          notification_type   = "ACTUAL"
          threshold           = 50
          threshold_type      = "PERCENTAGE"
        }
        actual_80_percent = {
          comparison_operator = "GREATER_THAN"
          notification_type   = "ACTUAL"
          threshold           = 80
          threshold_type      = "PERCENTAGE"
        }
        actual_100_percent = {
          comparison_operator = "GREATER_THAN"
          notification_type   = "ACTUAL"
          threshold           = 100
          threshold_type      = "PERCENTAGE"
        }
        forecast_100_percent = {
          comparison_operator = "GREATER_THAN"
          notification_type   = "FORECASTED"
          threshold           = 100
          threshold_type      = "PERCENTAGE"
        }
      }
    },
  ]

  notifications = {
    email = {
      addresses = [var.notification_email]
    }
  }

  tags = local.standard_tags
}
