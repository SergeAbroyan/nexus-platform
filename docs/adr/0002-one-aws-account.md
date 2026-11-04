# 0002. All environments share one AWS account

Status: accepted

## Context

AWS recommends separate accounts per environment under AWS Organizations. This
project is built and paid for by one person, and some resources can exist only
once per account: the GitHub OIDC provider, the hosted zone, and the image
repositories that every environment promotes from.

## Decision

Use one account. Separate environments by resource names, tags, KMS keys, and
IAM: each environment has its own CI role, trusted only from the GitHub
environment of the same name.

## Consequences

One bill and one set of account controls. The blast radius of an account-wide
mistake covers every environment, and IAM policies must use name patterns
instead of account boundaries. Moving to one account per environment later
means splitting `global` and adding cross-account image pulls.
