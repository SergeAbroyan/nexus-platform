# Nexus Platform Infrastructure

This repository defines the AWS infrastructure for Nexus with Terraform modules
and Terragrunt. The code contains three environments, `dev`, `staging`, and
`production`, and each environment can run in two AWS Regions as an
active-passive pair across one to three Availability Zones. Two settings per
environment decide what is actually deployed, so the same code serves a small
DEV and a highly available production.

Application source code lives in `nexus-applications`. Everything that runs
inside Kubernetes, including every add-on, lives in `nexus-gitops`. Terraform
owns the AWS resources, installs Argo CD, and hands each cluster one root
Application together with the AWS facts that `nexus-gitops` needs.

## What each environment deploys

| Environment | Regions | Availability Zones | Purpose |
| --- | --- | --- | --- |
| `dev` | `us-east-1` | 1 | Low-cost development |
| `staging` | `us-east-1`, standby `us-west-2` | 3 | Production-like testing |
| `production` | `us-east-1`, standby `us-west-2` | 3 | Highly available service |

The switches are in each `environment.hcl`:

- `standby_enabled` turns the `us-west-2` standby region on or off. When it is
  off, `terragrunt run --all` skips every `us-west-2` unit of that environment
  and refuses `plan` and `apply` inside them.
- `availability_zone_count` sets how many zones run nodes, NAT gateways, the
  database, the cache, and the load balancer. EKS and RDS require subnets in at
  least two zones, so subnets always exist in all three zones; they cost
  nothing, and with a count of 1 everything that runs is placed in the first
  zone.

## Architecture

```text
                 Users
                   │ HTTPS
          CloudFront + WAF  (one distribution per environment)
                   │ routes to the active region
        ┌──────────┴───────────┐
   us-east-1 (primary)    us-west-2 (standby, optional)
   internal NLB           internal NLB
   EKS + Istio + apps     EKS + Istio + apps
   PostgreSQL writer ───► PostgreSQL cross-region read replica
   Valkey, SQS            Valkey, SQS
        │                      ▲
   ECR (shared) ───────────────┘ image replication
```

- CloudFront is the only public entry point. It reaches each region's internal
  Network Load Balancer through a CloudFront VPC origin, so no load balancer is
  exposed to the internet. `active_region` decides which region receives
  traffic.
- In an environment with the standby enabled, the standby PostgreSQL database
  is a continuous read replica of the primary, and the standby API serves reads
  without changing the schema until the replica is promoted.
- With three zones, each region has a NAT gateway per zone, Multi-AZ
  PostgreSQL, Valkey replicas in other zones, system nodes in several zones,
  and at least two Karpenter controllers.

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
    ├── root.hcl          State backend, AWS provider, naming, region switch
    ├── account.hcl       Account-wide settings shared by every environment
    ├── _units/           One definition per unit type
    ├── global/           Account-wide unit, applied once
    ├── dev/
    │   ├── environment.hcl
    │   ├── edge/
    │   ├── us-east-1/    region.hcl, network, security, cluster, data, platform
    │   └── us-west-2/    region.hcl, network, security, cluster, data, platform
    ├── staging/          Same layout as dev
    └── production/       Same layout as dev
```

Each unit folder holds a small `terragrunt.hcl` that includes `root.hcl` and its
definition in `_units/`, so every environment and region uses the same unit
code. Settings live in three places:

- `account.hcl`: AWS account, primary and standby regions, domain, alert email,
  GitHub repositories, budget, and container registry
- `<environment>/environment.hcl`: the switches above and every sizing and
  retention setting of that environment
- `<environment>/<region>/region.hcl`: the region's network ranges; each
  environment and region uses its own non-overlapping `/16`

The `global` unit is shared because all environments live in one AWS account.
The GitHub OIDC provider, the ECR repositories, the Route 53 zone, and the
budget can exist only once per account, and images are promoted between
environments by commit SHA from the same repositories. `global` also creates
one infrastructure CI role per environment.

Resources are named `nexus` for account-wide resources, `nexus-<environment>`
for the environment edge, and `nexus-<environment>-<region code>` for regional
resources, for example `nexus-dev-use1`.

## Dependency order

```text
global (applied once)

Each enabled region:   network ──┐
                       security ─┼─► cluster ─► data ─► platform
                       global ───┘

us-west-2/data also waits for us-east-1/data, the replica source.
edge waits for global and for the platform unit of each enabled region.
```

`terragrunt dag graph --working-dir infrastructure/live/dev` prints the graph.
Independent units run in parallel, and destroy uses the reverse order.

## Prerequisites

- Terraform 1.11 or later (CI uses 1.17.0) and Terragrunt 1.1.5 or later (CI uses 1.2.1);
  `root.hcl` refuses older versions
- AWS CLI, `curl`, and `kubectl` 1.35 to 1.37 for EKS 1.36
- Credentials for the `aws_account_id` in `account.hcl`; the AWS provider
  refuses to run against any other account
- A domain that you own

The cluster unit adds the public IP address of whoever runs Terragrunt to the
EKS API allow list, detected with `https://checkip.amazonaws.com`. Put stable
administrator CIDRs in `cluster.public_access_cidrs` so that an apply from CI
does not remove your own access.

## Configuration

Before the first deployment set:

- `domain_name` in `account.hcl`; each environment is served at
  `<application_subdomain>.<domain_name>`, for example `nexus-dev.example.com`
- `cluster.public_access_cidrs` in the environment you deploy, for example
  `["203.0.113.10/32"]`
- `alert_email_address` and `monthly_budget_amount_usd` in `account.hcl` if
  needed

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

Apply the account-wide unit and delegate the domain to its hosted zone:

```bash
cd infrastructure/live/global
terragrunt apply
terragrunt output name_servers
```

Set those four name servers at your registrar. If the domain is registered with
Route 53, AWS created its own hosted zone for it; point the domain at the name
servers above and delete that extra zone. Wait until `dig NS <domain>` returns
the new name servers, because the CloudFront certificate is validated through
this zone.

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
`platform.gitops.deploy_key_revision` in each `environment.hcl`.

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

## Growing an environment

- More zones: raise `availability_zone_count`, set `nat_gateway_mode` to
  `one_per_az`, enable `multi_az` for the database and cache with at least two
  cache nodes, raise the node group sizes, and apply. Nodes, NAT gateways, the
  database standby, and cache replicas are added in the new zones.
- Standby region: set `standby_enabled = true` and run
  `terragrunt run --all apply`. The `us-west-2` units are created, its database
  starts as a replica of `us-east-1`, and CloudFront gains the second origin.

## Disaster recovery

This applies to environments with `standby_enabled = true`. Fail over to
`us-west-2`:

1. Set `active_region = "us-west-2"` in the environment's `environment.hcl`.
2. Promote the replica; this also creates a managed password secret for it:

   ```bash
   cd infrastructure/live/<environment>/us-west-2/data && terragrunt apply
   ```

3. Point External Secrets and the API at the promoted database's secret:

   ```bash
   cd ../platform && terragrunt apply
   ```

4. Send traffic to `us-west-2`:

   ```bash
   cd ../../edge && terragrunt apply
   ```

Promotion is one-way. To make `us-east-1` primary again, take a snapshot,
rebuild `us-east-1` as a replica of the promoted database, and switch
`active_region` back.

Limits: the Terraform state bucket and the CloudFront control plane are both in
`us-east-1`. During a complete `us-east-1` outage, promote the replica with
`aws rds promote-read-replica` and accept that CloudFront changes may be
delayed. A production setup should replicate the state bucket to the standby
region.

## Kubernetes platform

The platform unit follows the GitOps Bridge pattern. It installs Argo CD and
then a second Helm release, `argocd-gitops`, from the local chart
`modules/platform/charts/gitops`. That release holds two objects, both defined
in `modules/platform/bootstrap.tf`:

- the `bootstrap` AppProject, which may only create Argo CD `Application` and
  `AppProject` objects in the Argo CD namespace;
- the `bootstrap` Application, which renders the `bootstrap` chart in
  `nexus-gitops` and passes the cluster facts as its `cluster` Helm values.

The `bootstrap` chart creates every other Application, so add-on versions and
settings change through Git, not through Terraform. The release runs after
Argo CD because the Argo CD chart installs its CRDs as templates, and after the
Pod Identity roles so that controllers start with AWS credentials. Terraform
also configures the Argo CD health check for `Application` objects, which lets
the root Application roll out its children in sync waves: CRDs first, then the
controllers, then the node pools and storage class, then the workloads.

The cluster facts are everything `nexus-gitops` needs to know about AWS: the
environment, Region, cluster name, VPC, GitOps repository and revision,
application hostname, ingress port and target group, ECR registry, EBS key,
Karpenter node role and interruption queue, the alert topic, the Grafana
password secret, the PostgreSQL, Valkey, and SQS connection settings, and the
namespace and name of every service account that a Pod Identity role trusts.
Terraform owns those service accounts, defined once at the top of
`modules/platform/identities.tf` and, for Karpenter, in `environment.hcl`; the
add-ons that use them run in those namespaces. `values.schema.json` in the
`bootstrap` chart is the contract for the facts, so a missing or mistyped fact
fails the render. Application secrets never pass through Terraform state or
Git; External Secrets reads them from Secrets Manager with EKS Pod Identity.

`nexus-gitops` is private, so Argo CD reads it over SSH with a read-only GitHub
deploy key. The key lives in the Secrets Manager secret
`nexus/argocd/gitops-deploy-key`, which `global` creates and replicates to the
standby region. The platform unit reads it as an ephemeral value and hands it to
the Argo CD release as a write-only Helm value, so it is never written to
Terraform state or Git.

Terraform creates each region's internal Network Load Balancer and target
group in the workload zones. The `ingress-config` chart in `nexus-gitops` binds
the Istio gateway pods to that target group with a `TargetGroupBinding`, so the
load balancer exists before CloudFront needs it and one apply completes the
whole environment. Karpenter launches nodes only in the workload zones, because
only those subnets carry its discovery tag.

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
sampled at 1%, set by `tracing.samplingPercentage` in `nexus-gitops`. Loki and
Tempo use single-replica local volumes, which suits DEV; production should use
object storage.

## Cost

Rough monthly cost when running all the time:

- `dev` as configured, one region and one zone: about $300–360 for EKS, one NAT
  gateway, one system node, Karpenter nodes, single-AZ PostgreSQL and Valkey,
  the load balancer, CloudFront, and WAF
- `staging` or `production` with both regions and three zones: about
  $1,000–1,500 or more, depending on instance sizes

The account budget in `account.hcl` sends alerts at 50%, 80%, and 100% of the
monthly amount. Destroy environments that are not in use.

## Destroying

Karpenter nodes and Kubernetes volumes are not Terraform resources. Remove them
in each deployed region first, or they keep running and block VPC deletion:

```bash
kubectl delete nodepools --all
kubectl get nodeclaims
```

Wait until no node claims remain, then destroy the environment:

```bash
cd infrastructure/live/dev
terragrunt run --all destroy
```

Destroy an environment's standby region before setting
`standby_enabled = false`, because a disabled region refuses `plan` and
`apply`. Keep `global` while any environment exists.

Destroying a cluster does not delete its persistent volume claims, so the EBS
volumes behind them remain. In DEV the `nexus-gp3` StorageClass deletes a
volume when its claim is deleted; in staging and production volumes are
retained even then. After a teardown, delete leftover volumes in the EC2
console; each is tagged with the claim it served, in
`kubernetes.io/created-for/pvc/name`.

## Continuous validation and deployment

`.github/workflows/validate.yaml` runs on pull requests and pushes to `main`
without AWS credentials. It checks Terraform and Terragrunt formatting,
validates every Terragrunt unit and Terraform module, runs TFLint, and scans
with Checkov. Checkov excludes `CKV_TF_1` because the registry modules are
pinned to exact versions. A second, informational Checkov scan audits the
downloaded external modules.

`.github/workflows/deploy.yaml` plans or applies one chosen environment on
demand with GitHub OIDC. Apply `global` manually first, then:

- in `nexus-platform`, create GitHub environments `dev`, `staging`, and
  `production` with required reviewers, and set `AWS_INFRASTRUCTURE_ROLE_ARN`
  in each from the `global` output `infrastructure_ci_role_arns`
- in `nexus-applications`, set `AWS_ROLE_ARN` to the `global` output
  `application_ci_role_arn`, `AWS_REGION` to `us-east-1`, and the secret
  `GITOPS_TOKEN`

The application pipeline pushes images to `us-east-1`; ECR replicates them to
`us-west-2`. Actions are pinned to commit SHAs and Dependabot keeps them
current. The infrastructure CI roles have broad permissions; narrow them from
CloudTrail once real deployment behavior is known.
