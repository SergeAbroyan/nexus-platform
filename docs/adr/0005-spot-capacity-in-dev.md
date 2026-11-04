# 0005. DEV runs entirely on Spot capacity

Status: accepted

## Context

DEV runs around the clock for a single developer, and compute is its largest
variable cost.

## Decision

DEV's managed system node group uses Spot across several instance types, and
its Karpenter pools prefer Spot and fall back to On-Demand. Staging and
production keep the system and general pools On-Demand, and only the worker's
pool uses Spot everywhere. Karpenter handles interruption notices through its
SQS queue.

## Consequences

DEV compute costs roughly 60% less. A Spot reclaim restarts DEV pods, which the
`spot_interruption` FIS experiment rehearses. When Spot is unavailable, DEV
costs as much as On-Demand.
