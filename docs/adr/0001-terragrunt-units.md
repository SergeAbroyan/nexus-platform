# 0001. Every unit type has one Terragrunt definition shared by all environments

Status: accepted

## Context

Three environments in up to two regions need the same infrastructure with
different sizes. Copying Terraform per environment drifts, and one large state
per environment makes every plan slow and risky.

## Decision

Each layer is a Terraform module (`network`, `security`, `cluster`, `data`,
`platform`, `edge`, `global`) and has one definition in `live/_units/`. A unit
folder only includes its definition; sizes and switches live in
`environment.hcl`, region ranges in `region.hcl`, and account settings in
`account.hcl`. Terragrunt wires outputs between units through `dependency`
blocks, without mock outputs.

## Consequences

Every environment runs the same code, and a change to one layer plans only
that layer's state. Adding a region or an environment is a folder of small
files. The dependency graph must be applied in order, which `terragrunt run
--all` handles.
