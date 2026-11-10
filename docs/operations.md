# Operations

## Growing an environment

- More zones: raise `availability_zone_count`, set `nat_gateway_mode` to
  `one_per_az`, enable `multi_az` for the database and cache with at least two
  cache nodes, raise the node group sizes, and apply. Nodes, NAT gateways, the
  database standby, and cache replicas are added in the new zones.
- Standby region: set `standby_enabled = true` and run
  `terragrunt run --all apply`. The `us-west-2` units are created, its database
  starts as a replica of `us-east-1`, and CloudFront gains the second origin.

## Destroying

Karpenter nodes and Kubernetes volumes are not Terraform resources. Remove the
nodes in each deployed region first, or they keep running and block VPC
deletion. Stop the Argo CD application controller first, because self-healing
would recreate the node pools. Release the Application finalizers while the
cluster is still complete, so Terraform can uninstall Argo CD without its
controller. Remove the disruption budgets, so a single-replica workload cannot
hold a node for the full termination grace period:

```bash
kubectl scale statefulset argocd-application-controller -n argocd --replicas=0
kubectl get applications -n argocd -o name | xargs -I{} kubectl patch {} -n argocd --type merge -p '{"metadata":{"finalizers":null}}'
kubectl delete pdb --all --all-namespaces
kubectl delete nodepools --all
kubectl wait nodeclaims --all --for=delete --timeout=15m
kubectl delete ec2nodeclasses --all
```

Deleting the node classes last lets Karpenter remove the IAM instance profiles
it created for them; otherwise they outlive the cluster.

Then destroy the environment:

```bash
cd infrastructure/live/dev
terragrunt run --all destroy
```

If the `cluster` unit then stops on its node security group with
`DependencyViolation`, the VPC CNI left network interfaces behind for nodes
that no longer exist. They are detached, named `aws-K8S-<instance ID>`, and
safe to delete once their instances are terminated:

```bash
aws ec2 describe-network-interfaces --region us-east-1 \
  --filters Name=status,Values=available Name=description,Values='aws-K8S-*' \
  --query 'NetworkInterfaces[].NetworkInterfaceId' --output text \
  | xargs -n1 aws ec2 delete-network-interface --region us-east-1 --network-interface-id
```

Run the destroy again in the units that still have resources. A
`run --all destroy` cannot restart once the units at the top of the order are
gone, because they no longer have outputs for the units below them to read, so
destroy the remaining units one by one, starting with `cluster`, with
`terragrunt destroy` in each unit's folder.

With GuardDuty enabled, its runtime agent creates a VPC endpoint and a
security group in each cluster VPC that Terraform does not own. Set
`guardduty_enabled = false`, apply `global`, and delete the VPC endpoints for
the `com.amazonaws.<region>.guardduty-data` service, tagged
`GuardDutyManaged`, before destroying a network unit.

Destroy an environment's standby region before setting
`standby_enabled = false`, because a disabled region refuses `plan` and
`apply`. Keep `global` while any environment exists.

Backups follow the environment's settings: `backup_bucket_force_destroy` and
`data.backup.force_destroy` are `true` in DEV and staging, so destroying them
also deletes the Velero backups and the AWS Backup recovery points; in
production they are kept and must be deleted on purpose. EBS snapshots that
Velero took remain until their backup expires; delete leftovers in the EC2
console under Snapshots.

Destroying a cluster does not delete its persistent volume claims, so the EBS
volumes behind them remain. In DEV the `nexus-gp3` StorageClass deletes a
volume when its claim is deleted; in staging and production volumes are
retained even then. After a teardown, delete the leftover volumes; each is
tagged with the claim it served, in `kubernetes.io/created-for/pvc/name`:

```bash
aws ec2 describe-volumes --region us-east-1 \
  --filters Name=tag-key,Values=kubernetes.io/created-for/pvc/name Name=status,Values=available \
  --query 'Volumes[].VolumeId' --output text | xargs -n1 aws ec2 delete-volume --region us-east-1 --volume-id
```

DEV deletes its secrets immediately (`secret_recovery_window_in_days = 0`), so
it can be destroyed every evening and recreated the next day; AWS refuses to
create a secret whose name is still inside a recovery window. Staging and
production keep a recovery window.

## Disaster recovery

This applies to environments with `standby_enabled = true`. Fail over to
`us-west-2`:

1. Set `active_region = "us-west-2"` in the environment's `environment.hcl`.
2. Promote the replica; this also creates a managed password secret for it:

   ```bash
   cd infrastructure/live/<environment>/us-west-2/data && terragrunt apply
   ```

3. Point External Secrets and the API at the promoted database's secret:

   ```bash
   cd ../platform && terragrunt apply
   ```

4. Send traffic to `us-west-2`:

   ```bash
   cd ../../edge && terragrunt apply
   ```

Promotion is one-way. To make `us-east-1` primary again, take a snapshot,
rebuild `us-east-1` as a replica of the promoted database, and switch
`active_region` back.

Limits: the Terraform state bucket and the CloudFront control plane are both in
`us-east-1`. During a complete `us-east-1` outage, promote the replica with
`aws rds promote-read-replica` and accept that CloudFront changes may be
delayed. A production setup should replicate the state bucket to the standby
region.

## Backups and recovery

Three layers protect data, each for a different failure:

| Layer | What it protects | Where it lives |
| --- | --- | --- |
| RDS automated backups | Point-in-time restore of the database for `backup_retention_days` | RDS, same region |
| AWS Backup | Daily recovery points plus continuous backup of the database, kept for `data.backup.retention_days`: 7 days in DEV, 14 in staging, 35 in production | The `<name>-database` vault, encrypted with the RDS key |
| Velero | Kubernetes resources and volumes of the `nexus`, `cloudbeaver`, and `monitoring` namespaces, every night | The `<name>-velero-<account>` S3 bucket and EBS snapshots |

The AWS Backup vault is separate from the database: deleting the instance or
its automated backups leaves the vault's recovery points intact. In a standby
region the vault exists only after the replica is promoted. The Velero bucket
and snapshots stay in the cluster's region; the database replica covers the
loss of a region. Restore procedures are rehearsed in the drills of
`nexus-gitops`.

## Resilience experiments

The cluster unit creates three AWS Fault Injection Service experiment templates
per cluster and a role that FIS assumes to run them. They never run on their
own:

| Template | What it does | What should happen |
| --- | --- | --- |
| `spot_interruption` | Sends a two-minute Spot interruption notice to one running node | Karpenter receives the notice through its queue, starts a replacement, and drains the node; the API keeps serving |
| `system_node_failure` | Terminates half of the managed system nodes | EKS replaces them; controllers reschedule and Argo CD keeps reconciling |
| `zone_network_disruption` | Cuts all traffic of the node subnets in the first workload zone for five minutes | With three zones, traffic moves to the other zones; with one zone, as in DEV, the service is down for the duration |

```bash
cd infrastructure/live/dev/us-east-1/cluster
aws fis start-experiment --region us-east-1 \
  --experiment-template-id "$(terragrunt output -json fault_injection_experiment_template_ids | jq -r .spot_interruption)"
```

Watch the `Nexus Overview` dashboard and the API SLO burn rate during an
experiment. Run them in DEV or staging first.
