# Observability

## Alerts and observability

Each region has a KMS-encrypted SNS topic subscribed to `alert_email_address`.
Alertmanager publishes to it through EKS Pod Identity, and CloudWatch alarms
publish to it for RDS CPU, RDS free storage, Valkey memory per node, the age of
the oldest SQS job, and any dead-letter message. CloudWatch publishes as an AWS
service, so `security.kms.service_principals` allows `cloudwatch.amazonaws.com`
on the SNS key.

Alertmanager can also post warnings and critical alerts to Slack; the
webhook URL lives in the Secrets Manager secret `nexus/alerts/slack-webhook-url`,
which External Secrets reads with its Pod Identity.

Argo CD installs Prometheus, Grafana, Loki, Tempo, Pyroscope, OpenCost, Sloth,
and OpenTelemetry collectors in every cluster. Grafana reads CloudWatch through a read-only Pod Identity
role, Loki keeps seven days of logs, and Tempo keeps seven days of traces
sampled at 1%, set by `tracing.samplingPercentage` in `nexus-gitops`. Loki and
Tempo use single-replica local volumes, which suits DEV; production should use
object storage.

With `guardduty_enabled = true`, GuardDuty analyzes CloudTrail, VPC flow, DNS,
and EKS audit logs in both regions and installs its runtime agent in every
cluster as an EKS add-on. Findings appear in the GuardDuty console. The agent
creates a GuardDuty VPC endpoint in each cluster VPC; see
[Destroying](operations.md#destroying).
