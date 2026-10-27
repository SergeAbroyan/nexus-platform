module "budget" {
  source  = "appvia/budgets/aws"
  version = "4.0.0"

  budgets = [
    {
      name         = "${var.name}-monthly-cost"
      budget_type  = "COST"
      limit_amount = tostring(var.budget.monthly_limit_usd)
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
      addresses = [var.budget.notification_email]
    }
  }

  tags = var.tags
}
