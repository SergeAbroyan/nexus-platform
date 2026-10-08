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
  ├── RDS ────────────────────────────────┤
  ├── SQS                                 ├── Platform identities
  └── Valkey                              └── Workload identities
ECR ── CI identities
```

Independent components may run in parallel. `destroy` automatically uses the
reverse dependency order.

## Prerequisites

- Terraform 1.10 or newer, but earlier than 2.0
- Terragrunt
- AWS credentials for account `123456789012`
- Access to the existing state bucket `nexus-terraform-state-123456789012`

Confirm the active AWS identity before any deployment:

```bash
aws sts get-caller-identity
```

## Commands

Format all Terraform and Terragrunt files:

```bash
make format
```

Check formatting, Terragrunt configuration, and whitespace errors:

```bash
make check
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
