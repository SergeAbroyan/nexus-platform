# Nexus Platform Infrastructure

This repository defines the AWS infrastructure for Nexus with Terraform modules
and Terragrunt. Each environment runs in two AWS Regions as an active-passive
pair, and every region spreads its resources across three Availability Zones.

Application source code lives in `nexus-applications`. Helm charts and
environment values live in `nexus-gitops`. Terraform owns the AWS resources,
Argo CD, and the ApplicationSets that deploy those charts.

## Architecture

```text
                 Users
                   │ HTTPS
          CloudFront + WAF  (nexus.<domain>)
                   │ routes to the active region
        ┌──────────┴───────────┐
   us-east-1 (active)     us-west-2 (standby)
   internal NLB           internal NLB
   EKS + Istio + apps     EKS + Istio + apps
   PostgreSQL writer ───► PostgreSQL cross-region read replica
   Valkey, SQS            Valkey, SQS
   ECR ─────────────────► ECR replica
```

- **Primary region (`us-east-1`)** serves all traffic and holds the writable
  PostgreSQL database.
- **Standby region (`us-west-2`)** runs the same stack. Its PostgreSQL database
  is a continuous read replica of the primary, and ECR replicates every image
  to it. The standby API connects to the replica and skips schema changes.
- **CloudFront** is the only public entry point. It reaches each region's
  internal Network Load Balancer through a CloudFront VPC origin, so no load
  balancer is exposed to the internet. `active_region` decides which region
  receives traffic.
- Each region has three Availability Zones with a NAT gateway per zone,
  Multi-AZ PostgreSQL, a Valkey primary with a replica in another zone, two
  system nodes in different zones, two Karpenter controllers, and at least two
  pods for every application.

## Repository structure

```text
infrastructure/
├── bootstrap/            One-time Terraform state bucket
├── modules/              Seven reusable Terraform modules
│   ├── global/           GitHub CI roles, Route 53 zone, ECR and replication, budget
│   ├── network/          VPC, subnets, NAT gateways, flow logs
│   ├── security/         KMS keys, Grafana secret, regional alert topic
│   ├── cluster/          EKS, managed system nodes, Karpenter AWS resources
│   ├── data/             PostgreSQL, Valkey, SQS, CloudWatch alarms
│   ├── platform/         Pod Identity roles, ingress NLB, Argo CD and its seed objects
│   └── edge/             CloudFront, WAF, TLS certificate, application DNS records
└── live/
    ├── root.hcl          State backend, AWS provider, shared naming and tags
    ├── _units/           One definition per unit type, shared by every region
    └── dev/
        ├── environment.hcl   All DEV settings
        ├── global/           Environment-wide unit
        ├── edge/             Environment-wide unit
        ├── us-east-1/        region.hcl and five units
        └── us-west-2/        region.hcl and five units
```

Each unit folder holds a small `terragrunt.hcl` that includes `root.hcl` and its
definition in `_units/`. A setting is changed in one place: `environment.hcl`
for the environment, or `region.hcl` for a region's network.

Resources are named `<project>-<environment>` for environment-wide resources,
for example `nexus-dev`, and `<project>-<environment>-<region code>` for
regional resources, for example `nexus-dev-use1` and `nexus-dev-usw2`.

## Dependency order

Terragrunt derives the order from `dependency` blocks:

```text
Each region:   network ──┐
               security ─┼─► cluster ─► data ─► platform
               global ───┘

us-west-2/data also waits for us-east-1/data, the replica source.
edge waits for global and for the platform unit of both regions.
```

`terragrunt dag graph --working-dir infrastructure/live/dev` prints the full
graph. Independent units run in parallel, and destroy uses the reverse order.

## Prerequisites

- Terraform 1.10 or later (CI uses 1.16.6) and Terragrunt 1.1.5 or later;
  `root.hcl` refuses older versions
- AWS CLI, `curl`, and `kubectl` 1.34 to 1.36 for the EKS 1.35 clusters
- Credentials for account `123456789012`, the `aws_account_id` in
  `environment.hcl`; the AWS provider refuses to run against any other account
- A domain that you own

The cluster unit adds the public IP address of whoever runs Terragrunt to the
EKS API allow list, detected with `https://checkip.amazonaws.com`. Put stable
administrator CIDRs in `cluster.public_access_cidrs` so that an apply from CI
does not remove your own access.

## Configuration

All DEV settings are in `infrastructure/live/dev/environment.hcl`. Before the
first deployment set:

- `domain_name` to your domain; the application is served at
  `nexus.<domain_name>`
- `cluster.public_access_cidrs` to your stable administrator CIDRs, for example
  `["203.0.113.10/32"]`
- `alert_email_address` and `global.monthly_budget_amount_usd` if needed

Network ranges per region are in `us-east-1/region.hcl` and
`us-west-2/region.hcl`. The two VPCs use non-overlapping ranges so they can be
peered later.

## Deployment

Move the bootstrap state into the existing state bucket once:

```bash
terraform -chdir=infrastructure/bootstrap init -migrate-state \
  -backend-config="bucket=nexus-terraform-state-123456789012" \
  -backend-config="key=bootstrap/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="encrypt=true" \
  -backend-config="use_lockfile=true"
```

Create the DNS zone first and delegate the domain to it:

```bash
cd infrastructure/live/dev/global
terragrunt apply
terragrunt output name_servers
```

Set those four name servers at your registrar. If the domain is registered with
Route 53, AWS created its own hosted zone for it; point the domain at the name
servers above and delete that extra zone. Wait until `dig NS <domain>` returns
the new name servers, because the CloudFront certificate is validated through
this zone.

Deploy everything:

```bash
cd infrastructure/live/dev
terragrunt run --all plan
terragrunt run --all apply
```

Work on one unit:

```bash
cd infrastructure/live/dev/us-east-1/data
terragrunt plan
terragrunt apply
```

A first `run --all plan` stops at units whose dependencies have no state yet;
`run --all apply` creates them in order. Mock outputs are deliberately not
used, because they can hide wiring errors.

After the first apply, AWS sends one subscription email per region for the
alert topics. Choose **Confirm subscription** in both, or no alerts arrive.

Connect to a cluster:

```bash
aws eks update-kubeconfig --name nexus-dev-use1 --region us-east-1
aws eks update-kubeconfig --name nexus-dev-usw2 --region us-west-2
```

## Disaster recovery

The standby region is always running. Its database replicates continuously, so
failing over takes minutes instead of a rebuild.

Fail over to `us-west-2`:

1. Set `active_region = "us-west-2"` in `environment.hcl`.
2. Promote the replica. This also creates a managed password secret for the
   promoted database:

   ```bash
   cd infrastructure/live/dev/us-west-2/data && terragrunt apply
   ```

3. Point External Secrets and the API at the promoted database's secret:

   ```bash
   cd ../platform && terragrunt apply
   ```

4. Send traffic to `us-west-2`:

   ```bash
   cd ../../edge && terragrunt apply
   ```

Promotion is one-way. The old primary keeps its data but no longer receives
changes. To make `us-east-1` primary again, plan a failback: take a snapshot,
swap `primary_region` and `standby_region`, apply both data units so the old
primary is rebuilt as a replica, then switch `active_region` back.

Limits of this DEV design: the Terraform state bucket and the CloudFront
control plane are both in `us-east-1`. During a complete `us-east-1` outage,
promote the replica with `aws rds promote-read-replica` and accept that
CloudFront changes may be delayed. A production environment should replicate
the state bucket to the standby region.

## Kubernetes platform

The platform unit installs Argo CD and then a second Helm release,
`argocd-gitops`, from the local chart `modules/platform/charts/gitops`. That
release holds one AppProject and three ApplicationSets. It runs after Argo CD
because the Argo CD chart installs its CRDs as templates, and after the Pod
Identity roles so that controllers start with AWS credentials. Every generated
Application retries a failed sync with backoff, because on a new cluster some
Applications sync before another one has installed the CRDs they use.

Terraform creates each region's internal Network Load Balancer and target
group. The ingress chart in `nexus-gitops` binds the Istio gateway pods to that
target group with a `TargetGroupBinding`, so the load balancer exists before
CloudFront needs it and one apply completes the whole environment. The
Istio gateway namespace enforces the Restricted Pod Security Standard.

Terraform injects region-specific values into the ApplicationSets: the
regional ECR registry, PostgreSQL, Valkey and SQS endpoints, the database
secret and its region, the target group, and the Karpenter node role. Secrets
never pass through Terraform state, Helm values, or Git; External Secrets reads
them from Secrets Manager with EKS Pod Identity.

## Alerts and observability

Each region has a KMS-encrypted SNS topic subscribed to `alert_email_address`.
Alertmanager publishes to it through EKS Pod Identity, and CloudWatch alarms
publish to it for RDS CPU, RDS free storage, Valkey memory per node, the age of
the oldest SQS job, and any dead-letter message. CloudWatch publishes as an AWS
service, so `security.kms.service_principals` allows `cloudwatch.amazonaws.com`
on the SNS key.

Argo CD installs Prometheus, Grafana, Loki, Tempo, and OpenTelemetry collectors
in every cluster. Grafana reads CloudWatch through a read-only Pod Identity
role, Loki keeps seven days of logs, and Tempo keeps seven days of traces
sampled at 1%. Loki and Tempo use single-replica local volumes, which suits
DEV; production should use object storage.

## Cost

Running DEV in both regions with full multi-AZ HA costs roughly
$1,000–1,150 per month if it runs all the time: EKS, three NAT gateways, two
system nodes, Karpenter nodes, Multi-AZ PostgreSQL, two Valkey nodes, and a
load balancer per region, plus CloudFront and WAF. The budget in
`environment.hcl` sends alerts at 50%, 80%, and 100% of the monthly amount.
Destroy the environment when it is not in use.

## Destroying

Karpenter nodes and Kubernetes volumes are not Terraform resources. Remove them
in each region before destroying, or they keep running and block VPC deletion:

```bash
kubectl delete nodepools --all
kubectl get nodeclaims
```

Wait until no node claims remain, then run:

```bash
cd infrastructure/live/dev
terragrunt run --all destroy
```

Volumes created by persistent volume claims use the `Retain` policy; delete
them in the EC2 console when the data is no longer needed.

## Continuous validation and deployment

`.github/workflows/validate.yaml` runs on pull requests and pushes to `main`
without AWS credentials. It checks Terraform and Terragrunt formatting,
validates every Terragrunt unit and Terraform module, runs TFLint, and scans
with Checkov. Checkov excludes `CKV_TF_1` because the registry modules are
pinned to exact versions. A second, informational Checkov scan audits the
downloaded external modules.

`.github/workflows/deploy.yaml` plans or applies the whole DEV environment on
demand with GitHub OIDC. After the first manual apply:

- in `nexus-platform`, create a `dev` environment with required reviewers and
  set `AWS_INFRASTRUCTURE_ROLE_ARN` to the `global` unit output
  `infrastructure_ci_role_arn`
- in `nexus-applications`, set `AWS_ROLE_ARN` to the `global` output
  `application_ci_role_arn`, `AWS_REGION` to `us-east-1`, and the secret
  `GITOPS_TOKEN`

The application pipeline pushes images to `us-east-1`; ECR replicates them to
`us-west-2`. Actions are pinned to commit SHAs and Dependabot keeps them
current. The infrastructure CI role has broad permissions; narrow them from
CloudTrail once real deployment behavior is known.
