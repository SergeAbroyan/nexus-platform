# Nexus Platform Infrastructure

This repository defines the AWS infrastructure for Nexus. Terraform modules
describe reusable infrastructure components, while Terragrunt connects those
components for each environment and stores a separate state file for every
component.

Application source code belongs in `nexus-applications`. Project-owned Helm
charts and environment values belong in `nexus-gitops`. Terraform owns Argo CD,
its ApplicationSets, and infrastructure-derived platform configuration.

## Repository structure

```text
infrastructure/
├── bootstrap/                  # One-time remote-state bucket
├── modules/                    # Reusable Terraform module wrappers
└── live/
    ├── root.hcl                # Shared provider and remote-state settings
    └── dev/us-east-1/
        ├── environment.hcl     # DEV-specific values
        └── <component>/        # Deployable Terragrunt units
```

Every reusable module contains only `module` blocks for managed infrastructure.
The Argo CD module also ships a small local Helm chart, `charts/gitops`, for
its seed objects. Provider lock files are committed so local runs and CI select the same provider
builds; `.terraform/` working directories and state files remain ignored.

The bootstrap state bucket is deliberately outside `infrastructure/live`. It
must exist before Terragrunt can store remote state, and normal environment
destruction must not delete the bucket that contains the state history.

## Dependency order

Terragrunt calculates the order from `dependency` blocks instead of relying on
a manually maintained script.

```text
Budget
VPC ───────────────┐
                   ├── EKS ───────────────┐
KMS ───────────────┤                      ├── Argo CD + ApplicationSets
  ├── Platform secrets ───────────────────┤
  ├── SNS alert notifications ────────────┤
  ├── RDS ────────────────────────────────┤
  ├── SQS                                 ├── Platform identities
  └── Valkey                              └── Workload identities
RDS + Valkey + SQS ── CloudWatch alarms ── SNS alert notifications
KMS ── ECR ── CI identities ── EKS administrator access
DNS ── ACM certificate ───────────────────┤
  └── Optional CloudFront + WAF edge layer
  └── ExternalDNS identity ───────────────┘
```

Independent components may run in parallel. `destroy` automatically uses the
reverse dependency order.

## Prerequisites

- Terraform 1.16.6
- Terragrunt 1.1.5
- kubectl 1.34, 1.35, or 1.36 for the EKS 1.35 cluster
- AWS CLI
- AWS credentials for account `123456789012`, the `aws_account_id` in
  `environment.hcl`; the AWS provider refuses to run against any other account
- Access to the existing state bucket `nexus-terraform-state-123456789012`
- Ownership of the domain configured by `NEXUS_DNS_ZONE_NAME`

Confirm the active AWS identity before any deployment:

```bash
aws sts get-caller-identity
```

The local defaults use `platform.com` and `nexus.platform.com` as the planned
zone and application hostname. Override both values with a domain you own before
deployment. Terraform creates the Route 53 public hosted zone and ACM
certificate, but it cannot purchase or delegate the domain. DNS and the
certificate are intentionally separate state units so the hosted zone can exist
before ACM starts waiting for validation.

The bootstrap bucket already exists. Its local bootstrap state should be moved
to that protected bucket once, without recreating the bucket:

```bash
make bootstrap-init
```

Terraform asks for confirmation before migrating the local state to
`bootstrap/terraform.tfstate`. Keep the bootstrap unit separate from normal
environment destruction because it stores all other state files.

## Commands

Format all Terraform and Terragrunt files:

```bash
make format
```

Check formatting, Terragrunt configuration, and whitespace errors:

```bash
make check
```

Initialize and validate every reusable Terraform module without configuring a
backend or contacting AWS:

```bash
make validate-modules
```

Print the dependency graph:

```bash
make graph
```

Plan, apply, or destroy the complete DEV environment:

```bash
export EKS_PUBLIC_ACCESS_CIDR="$(curl -fsS https://checkip.amazonaws.com)/32"
export NEXUS_DNS_ZONE_NAME="example-owned-domain.com"
export NEXUS_INGRESS_HOST="nexus.${NEXUS_DNS_ZONE_NAME}"
make plan
make apply
make destroy
```

Use the smallest trusted CIDR possible, normally your current public IP with a
`/32` suffix. The preflight target checks that the CIDR is present and that the
active AWS account is `123456789012` before any plan, apply, or destroy.

Terragrunt prompts before applying or destroying the queued units. Do not add
`--non-interactive` during a manual deployment unless unattended execution is
intentional.

For another environment or region, override the defaults without changing
the Makefile:

```bash
make plan NEXUS_ENVIRONMENT=staging NEXUS_REGION=eu-central-1
```

On a brand-new environment, create and delegate DNS before the complete apply:

```bash
make apply-dns
make dns-nameservers
```

Buy or select the domain configured by `NEXUS_DNS_ZONE_NAME`, copy those four
name servers to the registrar, and wait for delegation to propagate. Then run
`make apply`. ACM validation cannot complete
until public DNS delegation works. Downstream state outputs also do not exist
before the first apply, so a complete first `plan` may stop at a dependency;
the first `apply` creates units in dependency order. Later plans evaluate the
entire graph normally. Fake deployment outputs are deliberately not used
because they can conceal wiring errors.

The EKS API is limited to `EKS_PUBLIC_ACCESS_CIDR`. Cluster administrator
entries use stable IAM ARNs: the `admin1` IAM user and the infrastructure CI
role. They never use the temporary identity of whoever happens to run
Terragrunt. For a team or production account, replace the IAM user with an AWS
IAM Identity Center role in `environment.hcl`.

The budget unit creates a USD 200 monthly DEV budget and emails alerts at 50%,
80%, and 100% of actual spend, plus a 100% forecast alert. Change
`monthly_budget_amount_usd` in `environment.hcl` to match your own limit.

The GitHub `dev` environment must define `AWS_INFRASTRUCTURE_ROLE_ARN`,
`EKS_PUBLIC_ACCESS_CIDR`, `NEXUS_DNS_ZONE_NAME`, and `NEXUS_INGRESS_HOST`.
`EKS_PUBLIC_ACCESS_CIDR` is the persistent trusted administrator CIDR. The
deployment workflow also discovers its temporary runner address for every run
and adds that address only for the duration of the plan or apply.

## Deployment boundary

Terraform installs the Argo CD controller after EKS is ready and seeds one
AppProject plus categorized ApplicationSets. Argo CD then installs external
platform charts and project-owned charts from `nexus-gitops`.

The seed objects are a second Helm release, `argocd-gitops`, that runs after
the Argo CD release. The Argo CD chart installs its CRDs as templates, so Helm
cannot create an AppProject or ApplicationSet in the same release on a new
cluster. Every generated Application retries a failed sync up to ten times
with backoff, because on a new cluster some Applications sync before another
Application has installed the CRDs they use.

Terraform also creates platform credentials that must exist before Kubernetes
workloads start. For example, the Grafana administrator password is generated
ephemerally and written directly to AWS Secrets Manager, so its value is not
stored in Git or Terraform state. External Secrets materializes it only in the
`monitoring` namespace.

The notifications unit creates a KMS-encrypted SNS topic and subscribes the
environment's alert email address. Alertmanager uses EKS Pod Identity with only
`sns:Publish` and the required KMS permissions; it does not store AWS access
keys. After the first apply, open the AWS subscription message sent to
`alerts@example.com` and choose **Confirm subscription**. AWS does not
deliver alert emails until that one-time confirmation is complete. The
always-firing Prometheus `Watchdog` alert is routed to a null receiver so it
does not generate email noise; firing and resolved operational alerts are sent
to SNS.

CloudWatch alarms use the same SNS topic for AWS-managed dependencies. They
cover sustained RDS CPU pressure, low RDS storage, Valkey memory pressure on
each cache node, old unprocessed jobs, and any message entering the SQS
dead-letter queue. Thresholds live in `environment.hcl`, while both alarm and
recovery transitions are delivered by email. CloudWatch publishes as an AWS
service rather than an IAM role, so `kms_key_service_principals` in
`environment.hcl` adds `cloudwatch.amazonaws.com` to the SNS key policy.

Grafana also receives a provisioned CloudWatch data source. Its pod uses a
dedicated EKS Pod Identity role and the AWS SDK default credential chain, so no
access keys are stored in Helm values or Kubernetes Secrets. The role is
read-only and permits CloudWatch metric, alarm, and log queries plus the AWS
resource-discovery calls required by Grafana's query editor.

Argo CD also installs Loki in monolithic mode for the DEV logging backend. Loki
keeps seven days of logs on a retained `20Gi` encrypted `nexus-gp3` volume and
exposes only an internal gateway Service. Grafana receives the Loki data source
through Helm provisioning. This single-replica filesystem design keeps DEV
costs low; a production environment should use S3-backed replicated Loki.

An OpenTelemetry Collector DaemonSet reads container logs from every worker
node, enriches them with Kubernetes metadata, and sends batches to Loki's
native OTLP endpoint. The collector excludes its own logs to avoid a feedback
loop and exposes only its internal metrics port; unused telemetry receivers are
disabled. Delivery retries and an in-memory queue absorb short Loki outages.

Argo CD installs Tempo in its single-binary mode as the DEV tracing backend.
Tempo accepts OTLP traces only inside the cluster, retains them for seven days
on a retained `20Gi` encrypted `nexus-gp3` volume, and publishes metrics for
Prometheus through a ServiceMonitor. Grafana provisions Tempo automatically and
can correlate traces with Loki logs by trace ID. This local-storage topology is
appropriate for DEV; production should use object storage and a distributed,
high-availability design.

A separate two-replica OpenTelemetry Collector Deployment is the internal trace
gateway. Applications and Istio proxies send OTLP spans to this gateway, which
limits memory, batches spans, and retries delivery to Tempo during short
outages. An Istio mesh-wide Telemetry policy selects the collector and samples
1% of requests. The gateway is deliberately separate from the node-level log
collectors because the two pipelines have different placement and scaling
requirements.

Argo CD installs ExternalDNS with a narrowly scoped Pod Identity role. It
creates the configured Nexus hostname from the Istio gateway Service after AWS assigns
the NLB hostname. The NLB terminates HTTPS with ACM and redirects HTTP to
HTTPS. Its scheme remains `internal`, so the hostname is reachable only from
networks that can reach the VPC; publishing it later requires a separate,
explicit public-access decision.

## Optional CDN and WAF

The `edge` Terragrunt unit provides an environment-controlled production edge
layer. DEV keeps `enable_cdn_origin_mode`, `enable_cdn`, and `enable_waf` set to
`false`, so it creates no CloudFront, WAF, or edge DNS resources and adds no CDN
cost. A production environment can enable them without changing reusable
Terraform code.

When enabled, the edge module creates a CloudFront distribution, Route 53 A and
AAAA aliases, HTTP/2 and HTTP/3 support, TLS 1.2 viewer enforcement, compression,
browser security headers, and an optional WAF. Static web-page requests use
CloudFront's optimized managed cache policy. `/api/*` accepts all API methods
but uses the managed disabled-cache policy and forwards viewer request data to
the origin.

The WAF baseline enables the AWS common, known-bad-input, and IP-reputation
managed rule groups plus a configurable per-IP rate limit. WAF metrics and
sampled requests are enabled in CloudWatch. Set `enable_waf = false` to use
CloudFront without WAF; enabling WAF while the CDN is disabled is rejected by
Terraform validation.

CloudFront uses a VPC origin so the origin load balancer remains private. The
Istio NLB is created asynchronously by Argo CD, so a new production environment
uses a deliberate two-stage bootstrap. First set `enable_cdn_origin_mode = true`
while leaving `enable_cdn = false`, apply, and wait for the ingress NLB. Then
copy its ARN and DNS name into `cdn_origin_load_balancer_arn` and
`cdn_origin_domain_name`, enable CDN and WAF, and apply again. This avoids
fragile plan-time load balancer discovery and prevents CloudFront from racing an
NLB listener update.

When `enable_cdn_origin_mode = true`, Argo CD omits the NLB TLS annotations and
the ExternalDNS application-hostname annotation. Port 443 remains a plain TCP
listener forwarding HTTP to Istio's port 8443; CloudFront terminates public TLS
and owns the application DNS aliases. This is required because CloudFront does
not accept an NLB with a TLS listener as a VPC origin.

Example production settings:

```hcl
enable_cdn_origin_mode = true
enable_cdn             = true
enable_waf             = true

cdn_origin_load_balancer_arn    = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/example/abc123"
cdn_origin_domain_name          = "internal-example.elb.us-east-1.amazonaws.com"
cdn_origin_http_port            = 443
cdn_origin_protocol_policy      = "http-only"
cdn_price_class                 = "PriceClass_200"
waf_rate_limit_per_five_minutes = 2000
```

## Continuous validation

`.github/workflows/validate.yaml` runs for pull requests and pushes to `main`.
It installs pinned Terraform and Terragrunt versions, runs the repository
formatting and HCL checks, and initializes and validates every module with its
backend disabled. The HCL checks need no AWS credentials because the account ID
comes from `environment.hcl` and the Helm provider reads the EKS connection
from unit inputs. TFLint checks every reusable module for Terraform issues, and
Checkov scans the infrastructure configuration for security misconfigurations.
Checkov excludes `CKV_TF_1` because Nexus uses Terraform Registry modules pinned
to exact versions; commit hashes are applicable to modules sourced from Git.
Project-owned Terraform is the blocking Checkov gate. A second informational
scan downloads and audits all external modules; it does not block because those
packages contain inactive optional resources that static analysis cannot
reliably eliminate. The validation workflow has read-only repository permission
and no AWS credentials, so it cannot plan, apply, or destroy infrastructure.
GitHub Actions are pinned to immutable commit SHAs, and Dependabot opens grouped
weekly updates so those pins stay maintainable.

`.github/workflows/deploy.yaml` is a manual plan/apply workflow. The first
deployment is manual because the infrastructure CI role does not exist until
Terraform creates it. After that apply, add these GitHub repository variables:

- `AWS_INFRASTRUCTURE_ROLE_ARN`: the `ci-identity` unit's
  `infrastructure_ci_iam_role_arn` output
- `EKS_PUBLIC_ACCESS_CIDR`: your persistent trusted administrator CIDR

Configure required reviewers on the GitHub `dev` environment before allowing
the `apply` option. The workflow temporarily adds its current runner CIDR while
preserving the administrator CIDR. It uses GitHub OIDC, so it needs no
permanent AWS access keys. The role includes the AWS services used by this
stack and access to only the Nexus Terraform state bucket; continue narrowing
service permissions from CloudTrail after real deployment behavior is known.
