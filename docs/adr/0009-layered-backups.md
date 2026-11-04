# 0009. Data is protected by RDS backups, AWS Backup, and Velero

Status: accepted

## Context

RDS automated backups disappear with the instance, Kubernetes volumes are not
covered by any database backup, and the read replica protects against a
regional outage but copies mistakes such as a dropped table instantly.

## Decision

Keep RDS automated backups for quick point-in-time restores, add an AWS Backup
plan with its own vault for recovery points that outlive the instance, and run
Velero in every cluster for Kubernetes resources and volumes.

## Consequences

Each failure has a restore path: a bad change, a deleted instance, a lost
namespace, or a lost region. Backups cost storage, and the restores are
rehearsed in the `nexus-gitops` drills rather than assumed to work.
