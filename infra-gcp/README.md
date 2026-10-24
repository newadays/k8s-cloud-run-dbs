# infra-gcp: the two-tier app's Google Cloud resources in Terraform

The Google Cloud counterpart of `infra-aws/two-tier.yaml`. Everything Modules 1 to 6 create by hand with `gcloud`, declared once:

| File | What it creates |
| --- | --- |
| `versions.tf`, `providers.tf` | Terraform and provider pins, remote state in a GCS bucket |
| `variables.tf` | `project`, `region`, `env` (staging/prod), toggles for Cloud Run and GKE |
| `apis.tf` | Enables the required APIs |
| `network.tf` | VPC, subnet with pod/service ranges, Cloud NAT, Private Services Access, deny-all ingress plus LB health-check allow |
| `registry.tf` | Artifact Registry repo `apps` |
| `database.tf` | Cloud SQL Postgres 16, private IP only, generated password in Secret Manager, backups and PITR, regional in prod |
| `iam.tf` | `api-sa` (cloudsql.client + one secret), `gke-nodes` (logs/metrics/pull), `ci-pipeline` (push images), Workload Identity binding |
| `cloudrun.tf` | Cloud Run service for the API over a Serverless VPC connector (Lab 1.1), on by default |
| `gke.tf` | Private regional GKE Standard cluster with Dataplane V2, Workload Identity, Binary Authorization, shielded nodes (Modules 3 and 4), off by default |
| `outputs.tf` | Connection name, private IP, secret id, registry path, Cloud Run URL |
| `envs/*.tfvars` | Per-environment shape (tier, toggles). Identity (`project`, `authorized_cidr`) is never in these files; `env.sh` exports it from `../.env` |

## Run it

```bash
# once: state bucket
gcloud storage buckets create gs://PROJECT-tfstate --location us-central1 --uniform-bucket-level-access
gcloud storage buckets update gs://PROJECT-tfstate --versioning

cd infra-gcp
source env.sh                      # exports TF_VAR_project and TF_VAR_authorized_cidr from the repo-root .env (copy .env.example first)
terraform init -backend-config="bucket=$PROJECT-tfstate"
terraform fmt -check && terraform validate
terraform plan -var-file envs/staging.tfvars -out staging.tfplan
terraform apply staging.tfplan
terraform output
```

Staging creates the network, database, secret, IAM, registry, and (once `image` is set) the Cloud Run service. Flip `create_gke = true` for Modules 3 and 4; the cluster costs about $0.30/hour while it exists.

## Things to try (each one is an interview question)

```bash
# in-place vs destroy-and-recreate
sed -i 's/db-f1-micro/db-g1-small/' envs/staging.tfvars && terraform plan -var-file envs/staging.tfvars   # ~ update in-place
# change database_version in database.tf and plan again                                                   # -/+ replacement

# drift
gcloud compute networks subnets update app-subnet --region us-central1 --no-enable-flow-logs
terraform plan -var-file envs/staging.tfvars                                                              # Terraform wants it back

# what is in state
terraform state list
terraform state pull | grep -c password                                                                   # yes, the password is in there

# policy checks (Lab 1b.4)
checkov -d . --compact
trivy config .
```

## Destroy

```bash
terraform destroy -var-file envs/staging.tfvars
```

Prod has `deletion_protection = true` on Cloud SQL and GKE; set `env = "staging"` in a plan first or flip the flag deliberately. `../teardown.sh` runs `terraform destroy` here when it finds state, then sweeps anything left.

## CI identity (Lab 5.1)

`ci-wif.tf` creates a Workload Identity Federation pool and a GitHub OIDC provider, and lets workflows in `github_repository` impersonate `ci-pipeline`. No key file exists. After `terraform apply`, hand the two outputs to the repository as variables. This needs an account with admin on the GitHub repo:

```bash
gh variable set PROJECT            --body "$PROJECT"
gh variable set REGION             --body "$REGION"
gh variable set WIF_PROVIDER       --body "$(terraform output -raw wif_provider)"
gh variable set CI_SERVICE_ACCOUNT --body "$(terraform output -raw ci_service_account)"
```

Then push a change under `two-tier-app/` and watch `.github/workflows/ci.yaml`. The run ends with a commit that writes the new digest into `charts/api/values-staging.yaml`.

Things to try:

```bash
# what the provider trusts
gcloud iam workload-identity-pools providers describe github --workload-identity-pool=github --location=global --format='value(attributeCondition)'
# who may impersonate ci-pipeline
gcloud iam service-accounts get-iam-policy ci-pipeline@$PROJECT.iam.gserviceaccount.com
# verify the signature CI attached (needs cosign)
cosign verify --certificate-identity-regexp 'github.com/newadays/k8s-cloud-run-dbs' --certificate-oidc-issuer https://token.actions.githubusercontent.com $REGION-docker.pkg.dev/$PROJECT/apps/api@sha256:...
```
