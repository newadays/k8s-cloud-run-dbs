# Teardown: delete everything the labs created

Run `teardown.sh` at the end of every lab day, and once more when you finish the course. It removes every cloud resource the labs create, in dependency order, and prints a verification list that should come back empty. Each step tolerates a resource that is already gone, so re-running it is safe. Interviewers ask about cost control and cleanup more often than people expect; being able to say "everything is in Terraform and torn down by one script" is a good answer.

Save it next to your Terraform directory, make it executable, and run it with your project id. `--dry-run` prints the commands without executing them.

```bash
chmod +x teardown.sh
PROJECT=my-project ./teardown.sh --dry-run   # review first
PROJECT=my-project ./teardown.sh             # delete
```

```bash
#!/usr/bin/env bash
# teardown.sh - delete everything the Cloud & Kubernetes interview-prep labs created.
#
# Usage:
#   PROJECT=my-project ./teardown.sh            # delete everything
#   PROJECT=my-project ./teardown.sh --dry-run  # print what would be deleted
#
# Every step is idempotent: a resource that does not exist is skipped, so the
# script can be re-run until the final verification section prints nothing.
set -uo pipefail

PROJECT="${PROJECT:?Set PROJECT=your-gcp-project-id}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"
CLUSTER="${CLUSTER:-two-tier}"
DB_INSTANCE="${DB_INSTANCE:-two-tier-db}"
VPC="${VPC:-two-tier-vpc}"
SUBNET="${SUBNET:-app-subnet}"
AR_REPO="${AR_REPO:-apps}"
RUN_SERVICE="${RUN_SERVICE:-api}"
VPC_CONNECTOR="${VPC_CONNECTOR:-two-tier-connector}"
WIF_POOL="${WIF_POOL:-github}"
WIF_PROVIDER="${WIF_PROVIDER:-github}"
TF_DIR="${TF_DIR:-./infra-gcp}"
AWS_STACKS="${AWS_STACKS:-two-tier-staging two-tier-prod}"
AWS_REGION="${AWS_REGION:-us-east-1}"
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

run() {
  echo "+ $*"
  if [[ $DRY_RUN -eq 0 ]]; then "$@" || echo "  (skipped: not found or already deleted)"; fi
}

gcloud config set project "$PROJECT" --quiet >/dev/null

echo "=== 1. Kubernetes objects that own cloud load balancers (delete before the cluster) ==="
if gcloud container clusters describe "$CLUSTER" --region "$REGION" >/dev/null 2>&1; then
  run gcloud container clusters get-credentials "$CLUSTER" --region "$REGION" --quiet
  run kubectl delete ingress --all -n two-tier --ignore-not-found --timeout=120s
  run kubectl delete managedcertificate --all -n two-tier --ignore-not-found
  run kubectl delete application --all -n argocd --ignore-not-found
  for ns in two-tier two-tier-staging two-tier-prod; do for rel in $(helm -n $ns list -q 2>/dev/null); do run helm -n $ns uninstall $rel; done; done
  run kubectl delete namespace two-tier two-tier-staging two-tier-prod argocd kyverno external-secrets --ignore-not-found --timeout=180s
fi

echo "=== 2. GKE cluster (Terraform state if present, otherwise gcloud) ==="
if [[ -f "$TF_DIR/terraform.tfstate" || -d "$TF_DIR/.terraform" ]]; then
  if [[ $DRY_RUN -eq 0 ]]; then
    ( cd "$TF_DIR" && terraform destroy -auto-approve -var-file "${TF_VARS:-envs/staging.tfvars}" ) || echo "  terraform destroy failed; falling back to gcloud"
  else
    echo "+ (cd $TF_DIR && terraform destroy -auto-approve)"
  fi
fi
run gcloud container clusters delete "$CLUSTER" --region "$REGION" --quiet
run gcloud container clusters delete "$CLUSTER" --zone "$ZONE" --quiet

echo "=== 2b. Plain VM and its firewall rule (Lab 1b.1) ==="
run gcloud compute instances delete api-vm --zone "$ZONE" --quiet
run gcloud compute firewall-rules delete allow-api --quiet

echo "=== 3. Cloud Run service and VPC connector (Lab 1.1) ==="
run gcloud run services delete "$RUN_SERVICE" --region "$REGION" --quiet
run gcloud compute networks vpc-access connectors delete "$VPC_CONNECTOR" --region "$REGION" --quiet

echo "=== 4. Cloud SQL (Lab 1.1) ==="
run gcloud sql instances patch "$DB_INSTANCE" --no-deletion-protection --quiet
run gcloud sql instances delete "$DB_INSTANCE" --quiet

echo "=== 5. Secrets and Artifact Registry ==="
run gcloud secrets delete db-password --quiet
run gcloud artifacts repositories delete "$AR_REPO" --location "$REGION" --quiet

echo "=== 6. Workload Identity Federation (Lab 5.1) ==="
run gcloud iam workload-identity-pools providers delete "$WIF_PROVIDER" \
  --workload-identity-pool "$WIF_POOL" --location global --quiet
run gcloud iam workload-identity-pools delete "$WIF_POOL" --location global --quiet

echo "=== 7. Service accounts (api-sa, ci-sa, nodes) ==="
for sa in api-sa ci-sa nodes; do
  run gcloud iam service-accounts delete "${sa}@${PROJECT}.iam.gserviceaccount.com" --quiet
done

echo "=== 8. Binary Authorization policy back to default ==="
if [[ $DRY_RUN -eq 0 ]]; then
  printf 'defaultAdmissionRule:\n  evaluationMode: ALWAYS_ALLOW\n  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG\nglobalPolicyEvaluationMode: ENABLE\n' > /tmp/binauthz-default.yaml
  run gcloud container binauthz policy import /tmp/binauthz-default.yaml
else
  echo "+ gcloud container binauthz policy import <default policy>"
fi

echo "=== 9. Network: leftover load balancer parts, Private Services Access, subnet, VPC ==="
# Forwarding rules, proxies, and backend services that an Ingress left behind
for fr in $(gcloud compute forwarding-rules list --global --filter="description~two-tier OR name~k8s" --format="value(name)" 2>/dev/null); do
  run gcloud compute forwarding-rules delete "$fr" --global --quiet
done
for fw in $(gcloud compute firewall-rules list --filter="network=$VPC" --format="value(name)" 2>/dev/null); do
  run gcloud compute firewall-rules delete "$fw" --quiet
done
run gcloud services vpc-peerings delete --service=servicenetworking.googleapis.com --network="$VPC" --quiet
for addr in $(gcloud compute addresses list --global --filter="purpose=VPC_PEERING AND network~$VPC" --format="value(name)" 2>/dev/null); do
  run gcloud compute addresses delete "$addr" --global --quiet
done
run gcloud compute networks subnets delete "$SUBNET" --region "$REGION" --quiet
run gcloud compute networks delete "$VPC" --quiet

echo "=== 9b. Terraform state bucket (keep unless you are done with the course) ==="
if [[ "${DELETE_STATE_BUCKET:-0}" == "1" ]]; then
  run gcloud storage rm -r "gs://${PROJECT}-tfstate"
else
  echo "  skipped: set DELETE_STATE_BUCKET=1 to remove gs://${PROJECT}-tfstate"
fi

echo "=== 9c. AWS CloudFormation stacks (Lab 1b.3), only if the aws CLI is configured ==="
if command -v aws >/dev/null && aws sts get-caller-identity >/dev/null 2>&1; then
  for st in $AWS_STACKS; do
    if aws cloudformation describe-stacks --stack-name "$st" --region "$AWS_REGION" >/dev/null 2>&1; then
      # prod has DeletionProtection on RDS; turn it off first or the delete fails
      dbid=$(aws cloudformation describe-stack-resource --stack-name "$st" --logical-resource-id Db --region "$AWS_REGION" --query 'StackResourceDetail.PhysicalResourceId' --output text 2>/dev/null || true)
      [[ -n "$dbid" && "$dbid" != "None" ]] && run aws rds modify-db-instance --db-instance-identifier "$dbid" --no-deletion-protection --apply-immediately --region "$AWS_REGION"
      run aws cloudformation delete-stack --stack-name "$st" --region "$AWS_REGION"
      [[ $DRY_RUN -eq 0 ]] && aws cloudformation wait stack-delete-complete --stack-name "$st" --region "$AWS_REGION" || true
    fi
  done
  for sec in $(aws secretsmanager list-secrets --region "$AWS_REGION" --query "SecretList[?starts_with(Name,'two-tier/')].Name" --output text 2>/dev/null); do
    run aws secretsmanager delete-secret --secret-id "$sec" --force-delete-without-recovery --region "$AWS_REGION"
  done
else
  echo "  skipped: aws CLI not configured"
fi

echo "=== 10. Local: kind cluster, Docker Compose volumes, images ==="
run kind delete cluster --name lab
[[ -f docker-compose.yml || -f compose.yaml ]] && run docker compose down -v --rmi local
run docker image prune -f

echo "=== 11. Verification (everything below should be empty) ==="
if [[ $DRY_RUN -eq 0 ]]; then
  gcloud container clusters list --format="value(name)"
  gcloud sql instances list --format="value(name)"
  gcloud run services list --region "$REGION" --format="value(name)"
  gcloud artifacts repositories list --location "$REGION" --format="value(name)"
  gcloud compute networks list --filter="name=$VPC" --format="value(name)"
  gcloud iam service-accounts list --filter="email~'^(api-sa|ci-sa|nodes)@'" --format="value(email)"
  gcloud secrets list --format="value(name)"
  gcloud compute instances list --format="value(name)"
  command -v aws >/dev/null && aws cloudformation list-stacks --region "$AWS_REGION" --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query "StackSummaries[?starts_with(StackName,'two-tier')].StackName" --output text 2>/dev/null
  echo "Check the billing report in 24 hours; the only lines should be zero or cents for logs and storage."
fi

cat <<'EOF'

Not deleted by this script (do these by hand):
  - GitHub repos two-tier-app and two-tier-config, plus the CONFIG_REPO_PAT secret in Actions
  - The DNS A record for api.example.com at your registrar
  - Cloud SQL backups are removed with the instance; the instance NAME is reserved for about a week
EOF
```

What the script covers, in order: Kubernetes Ingress and managed certificates (so their load balancers are released before the cluster goes), the GKE cluster through Terraform or gcloud, Cloud Run and its VPC connector, Cloud SQL (deletion protection off first), the secret and the Artifact Registry repo, the Workload Identity Federation pool and provider, the three service accounts, the Binary Authorization policy, leftover forwarding rules and firewall rules, Private Services Access peering and its reserved range, the subnet and VPC, the Lab 1b.1 VM and its firewall rule, the Terraform state bucket (only with DELETE\_STATE\_BUCKET=1), the Lab 1b.3 CloudFormation stacks and their secrets when the aws CLI is configured, then the local kind cluster and Docker Compose volumes.

Three things it cannot reach: the two GitHub repos and their Actions secret, the DNS record at your registrar, and the Cloud SQL instance name, which Google reserves for about a week after deletion.
