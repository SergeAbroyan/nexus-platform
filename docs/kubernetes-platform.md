# Kubernetes platform

The platform unit follows the GitOps Bridge pattern. It installs Argo CD and
then a second Helm release, `argocd-gitops`, from the local chart
`modules/platform/charts/gitops`. That release holds two objects, both defined
in `modules/platform/bootstrap.tf`:

- the `bootstrap` AppProject, which may only create Argo CD `Application` and
  `AppProject` objects in the Argo CD namespace;
- the `bootstrap` Application, which renders the `bootstrap` chart in
  `nexus-gitops` and passes the cluster facts as its `cluster` Helm values.

The `bootstrap` chart creates every other Application, so add-on versions and
settings change through Git, not through Terraform. The release runs after
Argo CD because the Argo CD chart installs its CRDs as templates, and after the
Pod Identity roles so that controllers start with AWS credentials. Terraform
also configures the Argo CD health check for `Application` objects, which lets
the root Application roll out its children in sync waves: CRDs first, then the
controllers, then the node pools and storage class, then the workloads.

The cluster facts are everything `nexus-gitops` needs to know about AWS: the
environment, Region, cluster name, VPC, GitOps repository and revision,
application hostname, ingress port and target group, ECR registry, EBS key,
Karpenter node role and interruption queue, the alert topic, the Grafana
password secret, the Slack webhook secret, the CI identity that signs images,
the Velero backup bucket,
the PostgreSQL, Valkey, and SQS connection settings, and the namespace and name
of every service account that a Pod Identity role trusts.
Besides the Nexus services, Pod Identity roles exist for the AWS Load Balancer
Controller, External Secrets, Alertmanager, Grafana, Kyverno and Trivy Operator
(read the Nexus images), KEDA (read the queue depth), and Velero (write the
backup bucket); each may do only what its add-on needs. Terraform owns those
service accounts, defined once at the top of
`modules/platform/identities.tf` and, for Karpenter, in `environment.hcl`; the
add-ons that use them run in those namespaces. `values.schema.json` in the
`bootstrap` chart is the contract for the facts, so a missing or mistyped fact
fails the render. Application secrets never pass through Terraform state or
Git; External Secrets reads them from Secrets Manager with EKS Pod Identity.

`nexus-gitops` is private, so Argo CD reads it over SSH with a read-only GitHub
deploy key. The key lives in the Secrets Manager secret
`nexus/argocd/gitops-deploy-key`, which `global` creates and replicates to the
standby region. The platform unit reads it as an ephemeral value and hands it to
the Argo CD release as a write-only Helm value, so it is never written to
Terraform state or Git.

Argo CD exposes metrics for its application controller, API server, and
repository server, and the monitoring stack in `nexus-gitops` scrapes them and
alerts when an Application stays degraded or out of sync or fails to sync.

### Admin tools

No admin tool has a public endpoint or an inbound port. Without Cloudflare,
reach each one with `kubectl port-forward`, for example
`kubectl port-forward -n argocd svc/argocd-server 8080:80`.

With Cloudflare configured, `cloudflared` runs in the `cloudflared` namespace
and opens outbound connections to Cloudflare. Each tool in
`admin_access.tools` in `account.hcl` gets the address
`https://<tool>-<environment>.<domain_name>`, for example
`https://argocd-dev.example.com`, and Cloudflare Access asks for a one-time
code sent to an address in `cloudflare.access_emails` before the tool loads.
`cloudflared` also checks the Access token on every request, so traffic that
did not pass Access is refused even if the Access application is changed or
deleted. The tools keep their own sign-in behind that. See
[ADR 0010](adr/0010-admin-access-through-cloudflare.md).

Cloudflare Access protects only names in a zone that Cloudflare serves, so the
whole domain moves from Route 53 to Cloudflare. The website keeps running on
CloudFront; Cloudflare only answers its DNS queries. When the domain already
runs on Route 53, the move keeps both DNS services answering with the same
records until every resolver has switched. For a new domain, set
`dns_authoritative = true` from the start and skip steps 6 and 9; no Route 53
zone is ever created.

1. Create a free Cloudflare account. Under Zero Trust choose a team name and the
   Free plan, and check that One-time PIN is listed under Settings →
   Authentication → Login methods.
2. Create an API token under My Profile → API Tokens with Account → Cloudflare
   Tunnel: Edit, Account → Access: Apps and Policies: Edit, Zone → Zone: Edit
   and Zone → DNS: Edit for all zones of the account. Load it without saving it
   in your shell history, and store the same value as the `CLOUDFLARE_API_TOKEN`
   secret of each GitHub environment, which the deploy workflow passes to
   Terragrunt:

   ```bash
   read -rs CLOUDFLARE_API_TOKEN && export CLOUDFLARE_API_TOKEN
   ```

3. In `identity.hcl`, set `cloudflare.account_id` and `cloudflare.access_team`,
   keep `dns_authoritative = false`, and apply `live/global`. Cloudflare now
   holds the zone, still pending, the tunnel for each environment in
   `admin_access.environments`, and the Access policy, while Route 53 still
   answers for the domain.
4. Copy each tunnel's token into its Secrets Manager secret. The pipe passes it
   from Cloudflare to AWS without printing it:

   ```bash
   cd infrastructure/live/global
   ACCOUNT_ID=<cloudflare account ID>
   TUNNEL_ID=$(terragrunt output -json admin_access | jq -r '.dev.tunnel_id')
   curl -fsS -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
     "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/cfd_tunnel/$TUNNEL_ID/token" \
     | jq -j .result \
     | aws secretsmanager put-secret-value --region us-east-1 \
         --secret-id nexus/cloudflare/dev-tunnel-token --secret-string file:///dev/stdin
   ```

5. Apply the environment, for example `terragrunt run --all apply` in
   `live/dev`. The edge unit copies the application and certificate validation
   records into Cloudflare, and the platform unit lets External Secrets read the
   token and tells Argo CD to deploy `cloudflared`.
6. Check that Cloudflare answers like Route 53, using one of the name servers in
   `terragrunt output cloudflare_name_servers`:

   ```bash
   dig +short nexus-dev.example.com @<cloudflare name server>
   ```

7. Set `dns_authoritative = true` and `keep_route53_zone = true`, and apply
   `live/global` again. The domain now points at Cloudflare's name servers;
   resolvers move over within 48 hours while the Route 53 zone keeps
   answering, and Cloudflare marks the zone active once it sees the change,
   usually within an hour, and sends an email.
8. Once the zone is active, apply `live/global` once more. Access accepts only
   names in an active zone, so the Access applications, the tunnel routes and
   the admin DNS names wait for this apply; Terraform reads the zone status
   itself. Check the status first with:

   ```bash
   curl -sS -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
     "https://api.cloudflare.com/client/v4/zones?name=example.com" | jq -r '.result[0].status'
   ```

9. After 48 hours, remove `keep_route53_zone` or set it to `false`, and apply
   `live/global`. The Route 53 zone is deleted, and the next apply of each
   environment's edge unit stops writing records to Route 53 and validates
   the certificate through Cloudflare alone.

The tunnel and its token live in `global`, so destroying and recreating an
environment keeps both. Rotating a token means running step 4 again and
restarting `cloudflared`.

### Argo CD sign-in

By default you sign in to Argo CD as `admin` with the password in the
`argocd-initial-admin-secret` Secret.

To sign in with GitHub instead:

1. In GitHub, open Settings → Developer settings → OAuth Apps → New OAuth App.
   Set the homepage to the Argo CD address and the callback URL to that address
   followed by `/api/dex/callback`. With Cloudflare configured, the address is
   `https://argocd-<environment>.<domain_name>`; without it, Argo CD is reached
   through `kubectl port-forward` at `http://localhost:8080`. A GitHub OAuth app
   has one callback URL, so each Argo CD address needs its own app. Generate a
   client secret.
2. Store the client secret without echoing it:

   ```bash
   read -rs CLIENT_SECRET
   printf '%s' "$CLIENT_SECRET" | aws secretsmanager put-secret-value --region us-east-1 \
     --secret-id nexus/argocd/github-oauth-client-secret --secret-string file:///dev/stdin
   unset CLIENT_SECRET
   ```

3. In `identity.hcl`, set `argocd_github_client_id` to the app's client ID; an
   empty value keeps GitHub sign-in off. The administrators are
   `administrators.github_logins`. Then apply the platform unit.

Terraform then enables Dex with a GitHub connector, gives the listed logins the
`admin` role, gives everyone else no access, and disables the local `admin`
account. The client secret reaches Argo CD the same way as the deploy key: an
ephemeral read and a write-only Helm value. After rotating it, increase
`platform.argocd.secrets_revision`.

### Admission policies

Kyverno runs in every cluster from `nexus-gitops` and rejects any Nexus pod
whose image has no keyless cosign signature from the `ci.yaml` workflow of
`nexus-applications` on the deployment branch. Terraform passes that workflow
identity as the `ciIdentity` fact, built from the `github` settings in
`account.hcl`, and gives the Kyverno admission controller a Pod Identity role
that can read only the Nexus repositories in its region.

Signatures and SBOM attestations are stored next to each image as OCI
referrers, without tags, and ECR deletes them together with their image. The
repositories therefore have no rule that expires untagged images; the only
lifecycle rule keeps the newest `maximum_image_count` images and artifacts in
each repository.

### Ingress

Terraform creates each region's internal Network Load Balancer and target
group in the workload zones. The `ingress-config` chart in `nexus-gitops` binds
the Istio gateway pods to that target group with a `TargetGroupBinding`, so the
load balancer exists before CloudFront needs it and one apply completes the
whole environment. Karpenter launches nodes only in the workload zones, because
only those subnets carry its discovery tag.
