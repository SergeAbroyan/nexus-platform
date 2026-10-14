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

The bootstrap state bucket is deliberately outside `infrastructure/live`. It
must exist before Terragrunt can store remote state, and normal environment
destruction must not delete the bucket that contains the state history.

## Dependency order

Terragrunt calculates the order from `dependency` blocks instead of relying on
a manually maintained script.

```text
VPC ───────────────┐
                   ├── EKS ───────────────┐
KMS ───────────────┤                      ├── Argo CD + ApplicationSets
  ├── Platform secrets ───────────────────┤
  ├── SNS alert notifications ────────────┤
  ├── RDS ────────────────────────────────┤
  ├── SQS                                 ├── Platform identities
  └── Valkey                              └── Workload identities
RDS + Valkey + SQS ── CloudWatch alarms ── SNS alert notifications
ECR ── CI identities
DNS ── ACM certificate ───────────────────┤
  └── ExternalDNS identity ───────────────┘
```

Independent components may run in parallel. `destroy` automatically uses the
reverse dependency order.

## Prerequisites

- Terraform 1.10 or newer, but earlier than 2.0
- Terragrunt
- AWS credentials for account `123456789012`
- Access to the existing state bucket `nexus-terraform-state-123456789012`
- Ownership of `platform.com` before deployment

Confirm the active AWS identity before any deployment:

```bash
aws sts get-caller-identity
```

The DEV configuration assumes `nexus.platform.com`. Terraform creates its
Route 53 public hosted zone and ACM certificate, but it cannot purchase the
domain. After buying `platform.com`, copy the `dns` unit's `name_servers`
output into the registrar's nameserver settings before applying downstream
units. ACM waits for DNS validation and cannot finish until that delegation is
active.

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
make plan
make apply
make destroy
```

Terragrunt prompts before applying or destroying the queued units. Do not add
`--non-interactive` during a manual deployment unless unattended execution is
intentional.

For another environment or region, override the defaults without changing
the Makefile:

```bash
make plan NEXUS_ENVIRONMENT=staging NEXUS_REGION=eu-central-1
```

On a brand-new environment, downstream state outputs do not exist yet, so a
complete `plan` can stop when it reaches a dependency with no state. The first
`apply` creates components in dependency order. After that initial deployment,
`make plan` can evaluate the entire graph normally. Avoid fake dependency
outputs for deployment plans because they can hide wiring errors.

## Deployment boundary

Terraform installs the Argo CD controller after EKS is ready and seeds one
AppProject plus categorized ApplicationSets. Argo CD then installs external
platform charts and project-owned charts from `nexus-gitops`.

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
recovery transitions are delivered by email.

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
creates `nexus.platform.com` from the Istio gateway Service after AWS assigns
the NLB hostname. The NLB terminates HTTPS with ACM and redirects HTTP to
HTTPS. Its scheme remains `internal`, so the hostname is reachable only from
networks that can reach the VPC; publishing it later requires a separate,
explicit public-access decision.

## Continuous validation

`.github/workflows/validate.yaml` runs for pull requests and pushes to `main`.
It installs pinned Terraform and Terragrunt versions, runs the repository
formatting and HCL checks, and initializes and validates every module with its
backend disabled. TFLint checks every reusable module for Terraform issues, and
Checkov scans the infrastructure configuration for security misconfigurations.
Checkov excludes `CKV_TF_1` because Nexus uses Terraform Registry modules pinned
to exact versions; commit hashes are applicable to modules sourced from Git.
The workflow has read-only repository permission and no AWS credentials, so it
cannot plan, apply, or destroy infrastructure.
