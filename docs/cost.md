# Cost

Rough monthly cost when running all the time:

- `dev` as configured, one region and one zone: about $280–330, or $65–75 a
  week, for EKS, one NAT gateway, one system node and two Karpenter nodes,
  single-AZ PostgreSQL and Valkey, the load balancer, CloudFront, WAF, KMS
  keys, CloudWatch logs, and volumes. Its nodes run on Spot, which is roughly
  60% cheaper than On-Demand; On-Demand nodes would add about $70–90
- `staging` or `production` with both regions and three zones: about
  $1,000–1,500 or more, depending on instance sizes

Two usage charges grow with activity rather than size. EKS audit logging
alone measured about 11 GB a day, about $5, on an otherwise idle DEV cluster,
so DEV sends every control-plane log type except `audit`
(`cluster.control_plane_log_types`); staging and production keep it. NAT
gateway processing is charged per GB, so S3 traffic, including ECR image
layers, uses the free S3 gateway endpoint instead.

Destroying DEV when it is not in use leaves only the `global` resources,
about $4 a month: the CloudTrail key, the shared secrets and their replicas,
the hosted zone, the ECR images, and the state and audit buckets.

The account budget in `account.hcl` sends alerts at 50%, 80%, and 100% of the
monthly amount. Destroy environments that are not in use; the hourly costs
stop, while `global` keeps costing a few dollars a month for KMS keys, secrets,
the hosted zone, and CloudTrail storage. Security Hub with AWS Config adds
roughly $10–30 a month, and GuardDuty a few dollars.

### Cost estimates

`.github/workflows/infracost.yaml` comments on every pull request with the
change in monthly cost that it causes, computed by Infracost from the
Terragrunt units of both branches. Create a free API key at infracost.io and
store it as the repository secret `INFRACOST_API_KEY`; without it the workflow
skips the estimate.
