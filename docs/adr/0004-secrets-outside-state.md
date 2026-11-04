# 0004. Secrets never enter Terraform state or Git

Status: accepted

## Context

Argo CD needs an SSH deploy key and, with GitHub sign-in, an OAuth client
secret. Passing them as normal Terraform values writes them to state in plain
text.

## Decision

Secrets live in Secrets Manager. Terraform creates each secret with a
placeholder and ignores later changes, so people set the real value with the
AWS CLI. The platform unit reads secrets as ephemeral values and passes them
to Helm as write-only values; `secrets_revision` forces a resend after
rotation. Inside the cluster, External Secrets reads application secrets with
Pod Identity.

## Consequences

State and Git contain no secret values, and rotation is a value change plus a
revision bump. Terraform 1.11 or later is required for write-only attributes.
