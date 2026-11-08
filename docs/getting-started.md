# Getting started

This guide deploys the platform into your own AWS account, from the
prerequisites to a running DEV environment. Pipelines and repository settings
are described in [CI and deployment](ci-cd.md).

## Prerequisites

- Terraform 1.11 or later (CI uses 1.17.0) and Terragrunt 1.1.5 or later (CI uses 1.2.1);
  `root.hcl` refuses older versions
- AWS CLI, `curl`, and `kubectl` 1.35 to 1.37 for EKS 1.36
- Credentials for the `aws_account_id` in `identity.hcl`; the AWS provider
  refuses to run against any other account
- A domain that you own

The cluster unit adds the public IP address of whoever runs Terragrunt to the
EKS API allow list, detected with `https://checkip.amazonaws.com`. Put stable
administrator CIDRs in `administrators.cidrs` in `identity.hcl` so that an apply from CI
does not remove your own access.

## Your values

Everything personal lives in `infrastructure/live/identity.hcl`, which Git
ignores. Start from the template:

```bash
cp infrastructure/live/identity.example.hcl infrastructure/live/identity.hcl
```

| Value | What to set |
| --- | --- |
| `aws_account_id` | The 12-digit AWS account; the AWS provider refuses any other account |
| `domain_name` | A domain you own; each environment is served at `<application_subdomain>.<domain_name>`, for example `nexus-dev.example.com` |
| `domain_registered_with_route53` | `true` when Route 53 registered the domain in this account, so Terraform points the domain at its name servers |
| `alert_email_address` | Receives alerts and budget notifications |
| `github_owner`, `github_owner_id` | The GitHub user or organization that owns the three repositories, and its numeric ID from `https://api.github.com/users/<owner>` |
| `administrators` | IAM users and GitHub logins with administrator rights, and stable CIDRs allowed to reach the EKS API, for example `["203.0.113.10/32"]` |
| `argocd_github_client_id` | Empty for the local `admin` account, or a GitHub OAuth app client ID |
| `cloudflare` | Empty `account_id` to keep DNS on Route 53, or your Cloudflare account |

The three repositories keep their names, `nexus-platform`, `nexus-gitops`,
and `nexus-applications`, under that owner, because the code builds repository
addresses and CI identities from the owner and these names.

Until `identity.hcl` exists, Terragrunt still validates the code against the
example values, but refuses `init`, `plan`, `apply`, and `destroy`, so nothing
touches an AWS account with placeholder values.

## Optional features

In `identity.hcl`:

- `cloudflare`: serve the domain from Cloudflare and publish the admin tools
  at `<tool>-<environment>.<domain_name>` behind Cloudflare Access; see
  [Admin tools](kubernetes-platform.md#admin-tools). Leave `account_id` empty
  to keep DNS on Route 53 and reach the tools with `kubectl port-forward`.
- `argocd_github_client_id`: sign in to Argo CD with GitHub instead of the
  local `admin` account; see
  [Argo CD sign-in](kubernetes-platform.md#argo-cd-sign-in).

In `account.hcl`:

- `monthly_budget_amount_usd`: the monthly budget whose alerts go to
  `alert_email_address`
- `guardduty_enabled`: GuardDuty threat detection with EKS audit log and EKS
  runtime monitoring in both regions
- `security_hub_enabled`: AWS Config recording and Security Hub checks against
  the AWS Foundational Security Best Practices and CIS benchmarks in both
  regions; see [Account security](security.md#account-security)
- `audit`: how long CloudTrail logs are kept, and whether destroying `global`
  deletes them

## Create the state bucket

Terraform keeps state in the S3 bucket `nexus-terraform-state-<account ID>`,
which `infrastructure/bootstrap` creates. A bucket cannot hold its own state
before it exists, so the first apply uses local state through an override
file, and the state then moves into the bucket:

```bash
printf 'terraform {\n  backend "local" {}\n}\n' > infrastructure/bootstrap/backend_override.tf
terraform -chdir=infrastructure/bootstrap init
terraform -chdir=infrastructure/bootstrap apply
rm infrastructure/bootstrap/backend_override.tf
terraform -chdir=infrastructure/bootstrap init -migrate-state \
  -backend-config="bucket=nexus-terraform-state-$(aws sts get-caller-identity --query Account --output text)" \
  -backend-config="key=bootstrap/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="encrypt=true" \
  -backend-config="use_lockfile=true"
rm infrastructure/bootstrap/terraform.tfstate*
```

Answer `yes` when Terraform offers to copy the local state into the bucket.
Git ignores the override file and local state files.

## Deployment

Apply the account-wide unit and delegate the domain to its hosted zone:

```bash
cd infrastructure/live/global
terragrunt apply
terragrunt output name_servers
```

With `domain_registered_with_route53 = true` in `identity.hcl`, the apply
also points the domain at the new zone's name servers, and keeps them in step if
the zone is ever recreated. When Route 53 registered the domain, it created a
hosted zone of its own that is now unused; delete it once in the Route 53
console, or with `aws route53 delete-hosted-zone --id <its ID>`. For a domain
registered elsewhere, set the flag to `false` and enter the four name servers at
your registrar. Wait until `dig NS <domain>` returns the new name servers,
because the CloudFront certificate is validated through this zone.

Give Argo CD read access to `nexus-gitops`. Create a key pair, store the
private key in the secret that `global` created, and delete the local copy:

```bash
ssh-keygen -t ed25519 -N "" -C argocd-nexus-gitops -f argocd-gitops
aws secretsmanager put-secret-value --region us-east-1 \
  --secret-id nexus/argocd/gitops-deploy-key \
  --secret-string file://argocd-gitops
rm argocd-gitops
```

In GitHub, open `nexus-gitops` → Settings → Deploy keys → Add deploy key, paste
the contents of `argocd-gitops.pub`, leave **Allow write access** off, and then
delete `argocd-gitops.pub`. To replace the key later, store the new private
key, add its public key in GitHub, and increase
`platform.argocd.secrets_revision` in each `environment.hcl`.

To receive alerts in Slack as well as by email, create a Slack app with an
incoming webhook for the alert channel, store its URL, and set
`alerting.slack.enabled: true` in `nexus-gitops`. The webhook URL is a secret,
so read it without echoing and pass it on standard input, which keeps it out of
the shell history and the process list:

```bash
read -rs WEBHOOK_URL
printf '%s' "$WEBHOOK_URL" | aws secretsmanager put-secret-value --region us-east-1 \
  --secret-id nexus/alerts/slack-webhook-url --secret-string file:///dev/stdin
unset WEBHOOK_URL
```

Deploy an environment:

```bash
cd infrastructure/live/dev
terragrunt run --all plan
terragrunt run --all apply
```

With the DEV settings this deploys `us-east-1` in one zone plus the edge. Work
on one unit:

```bash
cd infrastructure/live/dev/us-east-1/data
terragrunt plan
terragrunt apply
```

A first `run --all plan` stops at units whose dependencies have no state yet;
`run --all apply` creates them in order. Mock outputs are deliberately not
used, because they can hide wiring errors.

After the first apply, AWS sends a subscription email for each regional alert
topic. Choose **Confirm subscription**, or no alerts arrive.

Connect to a cluster:

```bash
aws eks update-kubeconfig --name nexus-dev-use1 --region us-east-1
```

Next, connect the pipelines of the three repositories as described in
[CI and deployment](ci-cd.md).
