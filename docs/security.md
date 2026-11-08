# Security

## Account security

`global` turns on account-wide controls in both regions:

- **CloudTrail:** one multi-region trail records every management API call to
  the `<name>-audit-<account>` bucket, encrypted with its own KMS key and with
  log file validation, kept for `audit.retention_days`.
- **IAM Access Analyzer:** reports any IAM role, KMS key, S3 bucket, or secret
  that is shared outside the account.
- **Cost Anomaly Detection:** AWS enables it by default with a daily email for
  unusual spending, so Terraform does not create a second monitor; check it
  under Billing → Cost Anomaly Detection.
- **GuardDuty** (`guardduty_enabled`) and **Security Hub**
  (`security_hub_enabled`) are off by default because they cost money. Security
  Hub needs AWS Config, which records resources once a day to keep its cost
  low; findings appear in the Security Hub console.
