# 0008. Image signatures are stored as OCI referrers in ECR

Status: accepted

## Context

Kyverno admits a Nexus image only with a valid cosign signature, so losing a
signature blocks that image the next time a pod starts. cosign 3 stores
signatures and attestations as untagged OCI referrers; ECR tags are immutable.

## Decision

Keep cosign's referrer format, which avoids tag conflicts with immutable
repositories. Remove the lifecycle rule that expired untagged images, because
the only untagged manifests are signatures and SBOMs; ECR deletes referrers
together with their image. Keep only the rule that limits each repository to
its newest images.

## Consequences

Signatures live exactly as long as their images. The image limit counts
artifacts too, so it is set to 300 to keep about 100 releases.
