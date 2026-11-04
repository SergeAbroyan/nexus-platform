# 0006. Pull requests get a cost estimate, not a Terraform plan

Status: accepted

## Context

A plan on every pull request is common practice. Here the EKS API accepts only
the administrators' addresses, so a GitHub-hosted runner cannot read the
Kubernetes resources that the platform unit manages. Atlantis would run plans
from inside AWS but needs a public webhook into the cluster and its own
credentials.

## Decision

Pull requests run formatting, validation, TFLint, Checkov, and Infracost.
Plans run on demand in `deploy.yaml`, behind the environment's reviewers, or
locally. Atlantis is not used.

## Consequences

Reviewers see the cost change but not the resource diff of a pull request.
Revisit with self-hosted runners inside the VPC, which would let CI plan
without exposing anything.
