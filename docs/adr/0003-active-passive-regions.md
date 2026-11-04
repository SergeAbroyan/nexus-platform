# 0003. Each environment can run active-passive in two regions behind CloudFront

Status: accepted

## Context

A regional outage should not take the service down for long, but running two
active regions needs a multi-writer database and doubles the cost of every
request path.

## Decision

`us-east-1` serves traffic and `us-west-2` stands by with its own cluster and a
cross-region PostgreSQL read replica. CloudFront is the only public entry point
and reaches each region's internal load balancer through a VPC origin;
`active_region` selects the origin. `standby_enabled` turns the standby off,
as in DEV.

## Consequences

No load balancer is public, and failover is three applies: promote the
replica, repoint the platform, switch the origin. Failover is manual and
one-way, and recovery time is minutes, not seconds.
