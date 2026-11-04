# Architecture decision records

Each record explains one decision: the situation, what was chosen, and what it
costs. Records are never rewritten; a changed decision gets a new record that
supersedes the old one.

| Record | Decision |
| --- | --- |
| [0001](0001-terragrunt-units.md) | Every unit type has one Terragrunt definition shared by all environments |
| [0002](0002-one-aws-account.md) | All environments share one AWS account |
| [0003](0003-active-passive-regions.md) | Each environment can run active-passive in two regions behind CloudFront |
| [0004](0004-secrets-outside-state.md) | Secrets never enter Terraform state or Git |
| [0005](0005-spot-capacity-in-dev.md) | DEV runs entirely on Spot capacity |
| [0006](0006-no-terraform-plan-on-pull-requests.md) | Pull requests get a cost estimate, not a Terraform plan |
| [0007](0007-alerts-without-a-paging-service.md) | Alerts go to email and Slack, without a paging service |
| [0008](0008-signatures-as-oci-referrers.md) | Image signatures are stored as OCI referrers in ECR |
| [0009](0009-layered-backups.md) | Data is protected by RDS backups, AWS Backup, and Velero |
