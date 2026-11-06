# 0010. Admin tools are published through Cloudflare Tunnel behind Cloudflare Access

Status: accepted

## Context

Argo CD, Grafana, Prometheus and the other admin tools have only cluster-internal
Services. `kubectl port-forward` works on one laptop at a time, drops when a
single connection fails, and does not work from a phone.

The alternatives were Tailscale, which needs a client on every device; CloudFront
with a WAF rule for the administrators' IP addresses, which breaks whenever a
home address changes and leaves the tools otherwise public; and AWS Verified
Access, which costs about $195 a month per application.

Cloudflare Access protects only names in a zone that Cloudflare serves, and the
free plan cannot take over a single subdomain, so the whole domain has to move
from Route 53 to Cloudflare.

## Decision

Cloudflare serves the domain's DNS. CloudFront still serves the website, and
Cloudflare holds its records as DNS-only, because only CloudFront can reach the
private load balancer through a VPC origin.

Each environment gets one remotely managed Cloudflare Tunnel, created in
`global` so that destroying and recreating the environment keeps the tunnel and
its token. `cloudflared` runs in the cluster and connects outward, so no
inbound port opens.

Each tool is published at `<tool>-<environment>.<domain>`. One level below the
domain keeps every name inside Cloudflare's free Universal SSL certificate,
which does not cover deeper names such as `argocd.dev.<domain>`.

Every tool has its own Access application with one shared allow policy, and
sign-in uses a one-time code sent by email, which needs no OAuth client
secret. Access accepts only names in an active zone, so Terraform reads the
zone status and creates the applications, tunnel routes and admin DNS names on
the first apply after Cloudflare activates the zone. `cloudflared` validates the Access token of every request, so a
missing or misconfigured Access application fails closed instead of exposing
the tool.

Terraform creates the tunnel without a secret. Cloudflare generates it, an
administrator copies the token into Secrets Manager once, and External Secrets
delivers it to the cluster, following [0004](0004-secrets-outside-state.md).

## Consequences

The tools are reachable from any device after an email sign-in, and nothing
depends on an administrator's IP address. Cloudflare is a second provider with
its own API token, read from `CLOUDFLARE_API_TOKEN` locally and from a GitHub
environment secret in CI. The DNS move is two applies of `global`, with both
services holding the same records in between; the Route 53 zone stays until
resolvers have moved and is removed in a later change. Access is free for up
to 50 users.
