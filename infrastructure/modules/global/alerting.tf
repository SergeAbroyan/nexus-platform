module "slack_webhook" {
  source  = "terraform-aws-modules/secrets-manager/aws"
  version = "2.2.0"

  name                    = "${var.name}/alerts/slack-webhook-url"
  description             = "Slack incoming webhook URL that Alertmanager posts warnings and critical alerts to"
  recovery_window_in_days = 7
  replica                 = { (var.standby_region) = {} }

  secret_string         = "Replace this value with the Slack incoming webhook URL."
  ignore_secret_changes = true

  tags = merge(var.tags, { Name = "${var.name}-alerts-slack-webhook-url" })
}
