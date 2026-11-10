# CI and deployment

## Continuous validation and deployment

`.github/workflows/validate.yaml` runs on pull requests and pushes to `main`
without AWS credentials. It checks Terraform and Terragrunt formatting,
validates every Terragrunt unit and Terraform module, runs TFLint, and scans
with Checkov. Checkov excludes five checks on purpose:

- `CKV_TF_1`: registry modules are pinned to exact versions, not commit hashes.
- `CKV2_AWS_3`: GuardDuty is configured for one account, not an AWS
  Organization.
- `CKV_AWS_252`: an SNS message for every CloudTrail log file adds noise
  without value.
- `CKV2_AWS_10`: CloudTrail logs stay in S3; copying them to CloudWatch Logs
  would cost per gigabyte for the same data.
- `CKV2_AWS_48`: AWS Config records global resources such as IAM in the
  primary region only, as AWS recommends, to avoid duplicate records.

Terraform plans are not run on pull requests: the EKS API accepts only the
administrator CIDRs and the address of whoever applies, so a GitHub-hosted
runner cannot read the Kubernetes resources of the platform unit. Plan with
`deploy.yaml` or locally before merging; Infracost shows the cost change on
the pull request.

`.github/workflows/deploy.yaml` plans or applies one chosen environment on
demand with GitHub OIDC. Apply `global` manually first, then:

- in `nexus-platform`, create GitHub environments `dev`, `staging`, and
  `production` with required reviewers, and set `AWS_INFRASTRUCTURE_ROLE_ARN`
  in each from the `global` output `infrastructure_ci_role_arns`
- in `nexus-platform`, add the secret `IDENTITY_HCL` with the contents of your
  `infrastructure/live/identity.hcl`, which the workflow writes before running
  Terragrunt, and, with Cloudflare configured, the secret
  `CLOUDFLARE_API_TOKEN`
- in `nexus-applications`, set `AWS_ROLE_ARN` to the `global` output
  `application_ci_role_arn`, `AWS_REGION` to `us-east-1`, and the secret
  `GITOPS_TOKEN`, and create the `production` environment with a required
  reviewer for its `Deploy` workflow

The application pipeline pushes images to `us-east-1`; ECR replicates them to
`us-west-2`. Actions are pinned to commit SHAs with their version alongside.
Renovate opens a weekly pull request per group: Terraform modules, Terraform
providers, the Argo CD chart, the Terraform, Terragrunt, and TFLint versions in
CI, and the actions; lock files are refreshed monthly. Gitleaks scans pull
requests for committed secrets, and `.gitleaksignore` lists the one historical
false positive. Install the local hooks once with `pre-commit install`. The
infrastructure CI roles have broad permissions; narrow them from CloudTrail
once real deployment behavior is known.
