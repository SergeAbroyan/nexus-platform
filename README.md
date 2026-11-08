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

## What it builds

- Three environments, `dev`, `staging`, and `production`, from the same code;
  each can run active-passive in two AWS Regions across one to three
  Availability Zones.
- Terragrunt units written once and shared by every environment, with every
  personal value in one ignored file, `identity.hcl`.
- EKS with Karpenter, PostgreSQL, Valkey, SQS, and CloudFront with WAF in front
  of a private load balancer.
- A GitOps bridge: Terraform installs Argo CD and hands it the cluster facts;
  `nexus-gitops` deploys everything else.
- Admin tools behind Cloudflare Tunnel and Access, without an inbound port.
- Secrets that never enter Git or Terraform state, and CI that reaches AWS
  through OIDC without stored keys.

## Quick start

1. Copy `infrastructure/live/identity.example.hcl` to `identity.hcl` and fill
   in your values.
2. Create the Terraform state bucket from `infrastructure/bootstrap`.
3. Apply `infrastructure/live/global` and store the Argo CD deploy key.
4. Run `terragrunt run --all apply` in `infrastructure/live/dev`.

[Getting started](docs/getting-started.md) walks through each step.

## Documentation

| Page | Contents |
| --- | --- |
| [Getting started](docs/getting-started.md) | Prerequisites, your values, the state bucket, the first deployment |
| [Architecture](docs/architecture.md) | Environments, architecture, repository structure, dependency order |
| [Kubernetes platform](docs/kubernetes-platform.md) | GitOps bridge, admin tools, Argo CD sign-in, admission policies, ingress |
| [Operations](docs/operations.md) | Growing and destroying environments, disaster recovery, backups, resilience experiments |
| [Security](docs/security.md) | Account security services |
| [Observability](docs/observability.md) | Alerts and observability |
| [Cost](docs/cost.md) | What the platform costs and how to keep it low |
| [CI and deployment](docs/ci-cd.md) | Validation, deployment workflows, repository settings |
| [Decision records](docs/adr/README.md) | Why each major choice was made |

## Related repositories

- `nexus-gitops`: everything that runs inside the Kubernetes clusters.
- `nexus-applications`: the API and worker source code and their pipelines.
