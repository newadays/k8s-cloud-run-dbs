# The CloudFormation workflow from Module 1b, on Google Cloud

Google has no CloudFormation. Its native IaC service, Infrastructure Manager, runs
Terraform for you, so the day-to-day commands are Terraform's. Each block below is
the GCP counterpart of the AWS block in Module 1b, in the same order.

```bash
cd infra-gcp
TFVARS=envs/staging.tfvars

# validate-template + cfn-lint  ->  fmt, validate, and a policy linter
terraform fmt -check -recursive
terraform validate
trivy config .                                        # or: checkov -d . --compact   (Lab 1b.4)

# first deploy: a saved plan is the change set; apply executes exactly that plan
terraform init -backend-config="bucket=winged-yeti-511917-t6-tfstate"
terraform plan  -var-file $TFVARS -out staging.tfplan
terraform apply staging.tfplan
terraform output                                      # describe-stacks --query Outputs

# preview a change the way a PR would: edit the input, plan, read it, then apply that plan
sed -i '' 's/db-f1-micro/db-g1-small/' $TFVARS
terraform plan -var-file $TFVARS -out bigger-db.tfplan
terraform show -no-color bigger-db.tfplan | grep -E 'must be replaced|will be (updated|created|destroyed)'
#   "updated in-place"  = CloudFormation Replacement=False
#   "must be replaced"  = Replacement=True  (the resource is destroyed and recreated)
terraform apply bigger-db.tfplan

# drift: change something in the console, then ask Terraform what no longer matches
gcloud compute networks subnets update app-subnet --region us-central1 --no-enable-flow-logs
terraform plan -var-file $TFVARS -refresh-only       # detect-stack-drift: shows what changed outside Terraform
terraform plan -var-file $TFVARS                      # and what apply would do to put it back
# To accept the console change instead of reverting it, edit the .tf to match, or:
terraform apply -var-file $TFVARS -refresh-only       # record the drift into state without touching the cloud

# rollback: Terraform does NOT roll back. A failed apply leaves everything that succeeded in place
# and records it in state. You fix forward, or re-apply the previous commit.
sed -i '' 's/db-g1-small/db-f1-micro/' $TFVARS
terraform apply -var-file $TFVARS                     # plan shows the revert, apply does it
# describe-stack-events  ->  the apply log itself, plus the audit trail in Cloud Logging:
gcloud logging read 'protoPayload.authenticationInfo.principalEmail="gbenga@autographos.org" AND protoPayload.methodName:("insert" OR "patch" OR "delete")' --freshness=1h --limit 20 --format='value(timestamp,protoPayload.methodName,protoPayload.resourceName)'

# cleanup: staging has deletion_protection=false; prod refuses until env or the flag is changed
terraform destroy -var-file $TFVARS
```

## If you want actual stacks: Infrastructure Manager

Infrastructure Manager is the closest thing to a CloudFormation stack. It stores
the Terraform state, runs plan and apply server-side with a service account, and
gives each deployment a name, a revision history, and a preview that is the
change set.

```bash
gcloud services enable config.googleapis.com
# a service account Infra Manager runs Terraform as; Editor is the lab shortcut, narrow it in prod
gcloud iam service-accounts create infra-manager
gcloud projects add-iam-policy-binding winged-yeti-511917-t6 --member serviceAccount:infra-manager@winged-yeti-511917-t6.iam.gserviceaccount.com --role roles/editor

SA=projects/winged-yeti-511917-t6/serviceAccounts/infra-manager@winged-yeti-511917-t6.iam.gserviceaccount.com
DEP=projects/winged-yeti-511917-t6/locations/us-central1/deployments/two-tier-staging

# deploy  (--local-source uploads this folder; drop versions.tf's backend block, Infra Manager keeps state itself)
gcloud infra-manager deployments apply $DEP --service-account $SA --local-source . --inputs-file envs/staging.tfvars
gcloud infra-manager deployments describe $DEP                       # describe-stacks
gcloud infra-manager revisions list --deployment $DEP                 # stack history

# change set: a preview you can read before applying
gcloud infra-manager previews create projects/winged-yeti-511917-t6/locations/us-central1/previews/bigger-db --deployment $DEP --service-account $SA --local-source . --inputs-file envs/staging.tfvars
gcloud infra-manager previews export projects/winged-yeti-511917-t6/locations/us-central1/previews/bigger-db   # the plan, as JSON and text

# cleanup: destroys the resources, then the deployment record
gcloud infra-manager deployments delete $DEP
```

## Concept map

| CloudFormation | Terraform on GCP | Infrastructure Manager |
| --- | --- | --- |
| Template `two-tier.yaml` | the `.tf` files in this folder | same files, uploaded |
| Parameters, `--parameter-overrides` | variables, `-var-file envs/staging.tfvars` | `--inputs-file` |
| Stack `two-tier-staging` | state file in the GCS bucket, one per `prefix` | deployment `two-tier-staging` |
| Change set | `terraform plan -out`, read with `terraform show` | preview |
| `Replacement=True` | `must be replaced` in the plan | same, in the exported preview |
| Outputs | `terraform output` | `deployments describe` |
| Drift detection | `plan -refresh-only` | `deployments describe` reports state, rerun apply to see diffs |
| Automatic rollback on failure | none: fix forward or apply the previous commit | none: new revision |
| `DeletionPolicy` / `DeletionProtection` | `deletion_protection` argument, `lifecycle { prevent_destroy }` | same, in the Terraform |
| `CAPABILITY_IAM` | no equivalent; the caller's own IAM permissions gate everything | the deployment service account's roles |
| `cfn-lint`, `cfn_nag` | `terraform validate`, `trivy config`, `checkov`, `tflint` | same, run in CI before apply |

## Lab 1b.4 policy checks, GCP version

Run from `infra-gcp`. Every command below was run against this folder; the counts are
what it reported on 2026-10-22.

```bash
# install once
pip3 install checkov          # Terraform + plan scanner, 70-odd GCP rules
brew install trivy gitleaks   # trivy: second ruleset; gitleaks is not on PyPI, brew only

# Terraform source: two scanners, two rulesets. Expect findings on the staging DB.
checkov -d . --compact --quiet --framework terraform          # 61 passed, 12 failed (all Cloud SQL flags + registry CMEK)
trivy config . --tf-vars envs/staging.tfvars --skip-files '*.tfplan'   # a saved .tfplan embeds OLD source; skip it or you scan stale code

# Terraform plan: catches values only known after evaluation (count, locals, data sources).
# plan.json holds the generated DB password in clear. It is gitignored; never commit or upload it.
terraform plan -var-file envs/staging.tfvars -out p.tfplan && terraform show -json p.tfplan > plan.json
checkov -f plan.json --repo-root-for-plan-enrichment . --compact --quiet
rm p.tfplan plan.json

# custom rule, the counterpart of rules/no-public-db.guard: policies/no_public_db.yaml
checkov -d . --external-checks-dir policies --check CKV2_CUSTOM_1 --framework terraform --compact --quiet

# CI gate: only HIGH and CRITICAL fail the build; the rest is a report
trivy config . --tf-vars envs/staging.tfvars --skip-files '*.tfplan' --severity HIGH,CRITICAL --exit-code 1
checkov -d . --framework terraform --check HIGH,CRITICAL --compact --quiet   # needs a Prisma key for severities; without one use --skip-check lists

# the repo itself: committed secrets. Run from the repo root.
(cd .. && gitleaks detect --source . --redact)                # scans history too; 2 commits, no leaks
```

What the 12 Checkov failures are: ten CIS logging flags on the Cloud SQL instance
(`log_checkpoints`, `log_disconnections`, `log_lock_waits`, `log_hostname`, pgAudit,
`log_min_messages`, and so on), one "latest major version" nag (Postgres 16 vs 17/18),
and one asking for a customer-managed KMS key on Artifact Registry. Two of them
contradict each other: CKV_GCP_57 wants slow-query logging off, CKV_GCP_111 wants
statement logging on. Scanners encode someone's benchmark, not your threat model;
decide, then record the decision with `#checkov:skip=CKV_GCP_57: slow-query log is
wanted on this app` above the resource.
