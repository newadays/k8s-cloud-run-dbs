# Module 1b: Compute, infrastructure as code, and their security implications

Every deployment decision in this course is a choice of compute (where the process runs), a way of declaring it (infrastructure as code), and a set of security consequences that follow from the first two. This module covers all three, with the labs' two-tier app as the running example. Budget about 90 minutes of reading and two labs.

**Part A: Compute resources**

Cloud compute is a spectrum of how much of the machine you still manage. Moving right means less to patch and operate, less control, and a bill that tracks usage more closely.

| Tier | You give the cloud | You still own | Google Cloud | AWS | Azure | Pick it when |
| --- | --- | --- | --- | --- | --- | --- |
| Bare metal | A rack slot | Everything incl. firmware | Bare Metal Solution | EC2 bare-metal instances | BareMetal Infrastructure | Licensing or hardware requirements forbid a hypervisor |
| Virtual machines | A machine image and size | OS patching, agents, scaling, SSH access | Compute Engine | EC2 | Virtual Machines | Legacy apps, custom kernels, GPUs, long-running stateful work |
| Managed VM groups | A template and a target | OS inside the image, app config | Managed Instance Groups | Auto Scaling Groups | VM Scale Sets | Stateless VM fleets behind a load balancer |
| Containers on managed Kubernetes | Images and manifests | Node pool choices, workloads, cluster add-ons | GKE Standard | EKS | AKS | Many services, portability, fine-grained control |
| Serverless Kubernetes | Images and manifests | Workloads only | GKE Autopilot | EKS Fargate / Auto Mode | AKS Automatic / virtual nodes | Kubernetes API without node management |
| Serverless containers | A container image | App code and config | Cloud Run | App Runner, ECS Fargate | Container Apps | Request-driven HTTP services, scale to zero |
| Functions | A function | Code | Cloud Functions / Cloud Run functions | Lambda | Azure Functions | Event handlers, glue, short bursts |

**Sizing vocabulary you will be asked about**

- vCPU and memory families: general purpose (`e2`, `n2` / `m5`, `t3` / `D`-series), compute-optimized (`c3` / `c6i` / `F`), memory-optimized (`m3` / `r6i` / `E`), accelerator (`a2`, `g2` / `p4`, `g5` / `NC`). Name the family, not the exact SKU.
- Pricing models: on-demand; committed-use / savings plans / reservations (1 or 3 years, 30 to 60 percent off); spot / preemptible (60 to 90 percent off, can be reclaimed with 30 seconds' notice, fine for stateless replicas and batch).
- Requests and limits on Kubernetes are how you buy slices of a node: a pod requesting 250m CPU and 256Mi memory is a quarter of a vCPU and a quarter of a GiB, reserved. The Cluster Autoscaler adds nodes when requests do not fit; the HPA adds pods when utilization is high; VPA tells you what the requests should have been.
- Regions and zones apply to all tiers: a zonal VM dies with its zone, a regional MIG or multi-zone node pool does not.

**Mapping the labs' two-tier app onto the spectrum**

| Option | What the API tier becomes | What the DB tier becomes | Trade-off |
| --- | --- | --- | --- |
| VMs | A MIG of 2+ VMs running gunicorn under systemd | Postgres on a VM with a persistent disk, or Cloud SQL | You patch the OS, write the health checks, and manage SSH; cheapest if you already run VMs |
| Cloud Run (Lab 1.1) | One service, scale 0 to N on request count | Cloud SQL over private IP | Fastest path to production for one stateless HTTP service; no cluster to secure |
| GKE Standard (Module 4) | A Deployment with 3 replicas, HPA, PDB | Cloud SQL via proxy sidecar | Full control and the Kubernetes ecosystem; you own node pools and upgrades |
| GKE Autopilot | Same manifests | Same | Per-pod billing, Google manages nodes, stricter pod security defaults; no DaemonSets or privileged pods |

The interview answer to "which compute would you pick" is a sentence about the workload, then a sentence about the team: "One stateless HTTP API with a managed database is a Cloud Run or App Runner job; I would move to Kubernetes when there are several services, custom networking, sidecars, or a platform team that wants one control plane for everything."

**Lab 1b.1 (30 min): the same API on a plain VM, so you feel what Kubernetes replaces**

```bash
gcloud compute instances create api-vm --zone us-central1-a --machine-type e2-small \
  --image-family debian-12 --image-project debian-cloud --tags api \
  --metadata startup-script='#!/bin/bash
apt-get update && apt-get install -y python3-pip python3-venv git
git clone https://github.com/YOUR_ORG/two-tier-app /opt/app
cd /opt/app && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
cat >/etc/systemd/system/api.service <<EOF
[Unit]
Description=two-tier api
After=network.target
[Service]
User=nobody
WorkingDirectory=/opt/app
ExecStart=/opt/app/.venv/bin/gunicorn --bind 0.0.0.0:8080 app:app
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl enable --now api'
gcloud compute firewall-rules create allow-api --allow tcp:8080 --target-tags api --source-ranges YOUR_IP/32
gcloud compute ssh api-vm --zone us-central1-a -- sudo journalctl -u api -f
```

Then list what you had to do yourself that Module 0 and Module 4 did for you: install the runtime, write a service unit, open a firewall rule, read logs over SSH, and (not done here) health checks, rolling updates, and scaling. Delete it: `gcloud compute instances delete api-vm --zone us-central1-a` and `gcloud compute firewall-rules delete allow-api`. The teardown script covers both.

**Part B: Infrastructure as code with Terraform**

Infrastructure as code means the cloud resources are declared in files, reviewed in pull requests, and created by a tool that converges reality to the files. The payoff is the same as for application code: history, review, repeatability, and a way to rebuild from nothing. The console becomes a read-only view.

**How Terraform works, in five words: declare, plan, apply, state, providers.**

| Concept | What it is | Why interviewers ask |
| --- | --- | --- |
| Provider | Plugin that knows a cloud's API (`google`, `aws`, `azurerm`, `kubernetes`, `helm`) | Terraform is multi-cloud because providers are, not because one config runs everywhere |
| Resource | One declared object: `resource "google_sql_database_instance" "db" {}` | Address `google_sql_database_instance.db` is how you refer to it everywhere |
| State | A JSON file mapping declared resources to real IDs | Lose it and Terraform thinks nothing exists; it also contains secrets in plaintext |
| `terraform plan` | Diff between config, state, and the real cloud | The thing you review in a PR; `-out plan.tfplan` pins what `apply` will do |
| `terraform apply` | Executes the plan in dependency order | Creates, updates in place, or destroys and recreates (the plan says which: `~` vs `-/+`) |
| Module | A reusable folder of resources with inputs and outputs | How teams share a "private GKE cluster" or "Cloud SQL with private IP" pattern |
| Workspace / backend | Where state lives (GCS, S3 + DynamoDB lock, Terraform Cloud) and how environments are separated | Remote state with locking is non-negotiable for a team |
| Import | Adopt a resource that already exists into state | How you bring a console-created cluster under code without recreating it |

**Lab 1b.2 (60 min): the two-tier app's cloud resources in Terraform**

Layout for the repo:

```
infra-gcp/                  # complete and ready to run; the Google Cloud counterpart of infra-aws/two-tier.yaml
  versions.tf               # Terraform and provider pins, remote state in a GCS bucket
  providers.tf
  variables.tf              # project, region, env (staging|prod), toggles: create_cloud_run, create_gke
  apis.tf                   # enables the required APIs
  network.tf                # VPC, subnet with pod/service ranges, Cloud NAT, Private Services Access, firewall
  registry.tf               # Artifact Registry repo "apps"
  database.tf               # Cloud SQL Postgres 16, private IP only, password generated into Secret Manager
  iam.tf                    # api-sa, nodes, ci-sa; Workload Identity binding
  cloudrun.tf               # Cloud Run service over a Serverless VPC connector (Lab 1.1), on by default
  gke.tf                    # private regional GKE Standard cluster (Modules 3 and 4), off by default
  outputs.tf
  envs/staging.tfvars
  envs/prod.tfvars
  README.md                 # run, experiment, destroy
```

The pieces Module 3 did not already show (abridged; the files in infra-gcp/ carry the full versions with Cloud NAT, firewall rules, flow logs, backups, and the Cloud Run service):

```hcl
# backend.tf: state in a bucket with versioning; create the bucket once by hand
terraform {
  required_version = ">= 1.6"
  backend "gcs" { bucket = "PROJECT-tfstate"  prefix = "two-tier" }
  required_providers { google = { source = "hashicorp/google", version = "~> 6.0" } }
}

# network.tf
resource "google_compute_network" "vpc" {
  name                    = "two-tier-vpc"
  auto_create_subnetworks = false
}
resource "google_compute_subnetwork" "app" {
  name                     = "app-subnet"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = "10.10.0.0/24"
  private_ip_google_access = true
  secondary_ip_range { range_name = "pods"      ip_cidr_range = "10.20.0.0/16" }
  secondary_ip_range { range_name = "services"  ip_cidr_range = "10.30.0.0/20" }
}
resource "google_compute_global_address" "psa" {       # range Cloud SQL will live in
  name          = "psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}
resource "google_service_networking_connection" "psa" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa.name]
}

# database.tf
resource "random_password" "db" { length = 32  special = false }
resource "google_secret_manager_secret" "db_password" {
  secret_id   = "db-password"
  replication { auto {} }
}
resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db.result
}
resource "google_sql_database_instance" "db" {
  name                = "two-tier-db"
  database_version    = "POSTGRES_16"
  region              = var.region
  deletion_protection = var.env == "prod"
  depends_on          = [google_service_networking_connection.psa]
  settings {
    tier              = var.db_tier                  # db-f1-micro in staging, db-custom-2-7680 in prod
    availability_type = var.env == "prod" ? "REGIONAL" : "ZONAL"
    ip_configuration {
      ipv4_enabled    = false                          # no public IP
      private_network = google_compute_network.vpc.id
    }
    backup_configuration { enabled = true  point_in_time_recovery_enabled = true }
  }
}
resource "google_sql_database" "app" { name = "app"  instance = google_sql_database_instance.db.name }
resource "google_sql_user" "app" {
  name     = "app"
  instance = google_sql_database_instance.db.name
  password = random_password.db.result
}

# iam.tf
resource "google_service_account" "api"   { account_id = "api-sa" }
resource "google_service_account" "nodes" { account_id = "nodes" }
resource "google_project_iam_member" "api_sql" {
  project = var.project
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.api.email}"
}
resource "google_secret_manager_secret_iam_member" "api_secret" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}
resource "google_service_account_iam_member" "wi" {        # Workload Identity: KSA two-tier/api -> api-sa
  service_account_id = google_service_account.api.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project}.svc.id.goog[two-tier/api]"
}
resource "google_project_iam_member" "nodes" {
  for_each = toset(["roles/logging.logWriter", "roles/monitoring.metricWriter", "roles/artifactregistry.reader"])
  project  = var.project
  role     = each.value
  member   = "serviceAccount:${google_service_account.nodes.email}"
}
```

Run it the way a pipeline would:

```bash
# once: the state bucket
gcloud storage buckets create gs://PROJECT-tfstate --location us-central1 --uniform-bucket-level-access
gcloud storage buckets update gs://PROJECT-tfstate --versioning

cd infra-gcp
sed -i 's/PROJECT/your-project-id/; s#YOUR_IP#'"$(curl -s ifconfig.me)"'#' envs/staging.tfvars
terraform init -backend-config="bucket=your-project-id-tfstate"
terraform fmt -check && terraform validate
terraform plan -var-file envs/staging.tfvars -out staging.tfplan   # read every line
terraform apply staging.tfplan
terraform state list                                                # what Terraform now owns
terraform output
```

Three things to try before moving on, because each one is an interview question:

1. Change `db_tier` in the tfvars and plan again. The plan shows `~ update in-place`. Change `database_version` and it shows `-/+ destroy and then create replacement`: Terraform tells you when a change is destructive, and `prevent_destroy` or `deletion_protection` is how you refuse it.
2. Turn off the subnet's flow logs in the console, then `terraform plan`. That is drift; Terraform will plan to revert it. Teams run a scheduled plan to detect drift.
3. `terraform state pull | grep -A2 password`. The database password is in state in plaintext. That is why state lives in a private, versioned, encrypted bucket with IAM on it, never in Git.

**Alternatives to know by name.** Pulumi (same model, real programming languages); OpenTofu (open-source Terraform fork); Config Connector / Crossplane (declare cloud resources as Kubernetes objects, reconciled by a controller: the GitOps model from Module 5 applied to infrastructure); and the cloud-native tools, CloudFormation and Bicep, next.

**Part C: CloudFormation**

CloudFormation is AWS's native infrastructure-as-code service. You hand it a template (YAML or JSON) and it creates a *stack*: a set of resources it owns, tracks, and can update or delete as a unit. The biggest conceptual difference from Terraform is that there is no state file to manage; AWS keeps the state inside the service. The second is that it only speaks AWS.

|  | Terraform | CloudFormation |
| --- | --- | --- |
| Clouds | Any, via providers | AWS only (Google's equivalent is Deployment Manager, now de-emphasized in favor of Terraform and Config Connector; Azure's is ARM / Bicep) |
| Language | HCL | YAML or JSON; CDK generates it from TypeScript, Python, etc. |
| State | A file you store and protect | Held by the service; nothing to leak or lose |
| Preview | `terraform plan` | Change sets |
| Unit of deployment | A root module / workspace | A stack; nested stacks and StackSets for many accounts and regions |
| Failure handling | Partial apply; fix and re-apply | Automatic rollback to the last good state by default |
| Drift | Shows in the next plan | `detect-stack-drift` on demand |
| Reuse | Modules, registries | Nested stacks, modules, CDK constructs |
| Secrets | Written to state in plaintext | Dynamic references pull from Secrets Manager / SSM at deploy time and never land in the template |
| Permissions model | Whatever credentials run Terraform | Optionally a stack *service role* so the deployer needs only `cloudformation:*` |

**The two-tier app on AWS, as one template.** This is the CloudFormation counterpart of Lab 1b.2: VPC, private subnets, RDS Postgres with no public access, a generated password in Secrets Manager, and an App Runner service (the Cloud Run equivalent) with least-privilege roles. Save as `infra-aws/two-tier.yaml`.

```yaml
AWSTemplateFormatVersion: "2010-09-09"
Description: Two-tier app - App Runner API in front of a private RDS Postgres

Parameters:
  Env:      { Type: String, AllowedValues: [staging, prod], Default: staging }
  ImageUri: { Type: String, Description: ECR image, e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com/api@sha256:... }
  DbClass:  { Type: String, Default: db.t4g.micro }

Conditions:
  IsProd: !Equals [!Ref Env, prod]

Resources:
  Vpc:
    Type: AWS::EC2::VPC
    Properties: { CidrBlock: 10.10.0.0/16, EnableDnsSupport: true, EnableDnsHostnames: true }
  SubnetA:
    Type: AWS::EC2::Subnet
    Properties: { VpcId: !Ref Vpc, CidrBlock: 10.10.1.0/24, AvailabilityZone: !Select [0, !GetAZs ""] }
  SubnetB:
    Type: AWS::EC2::Subnet
    Properties: { VpcId: !Ref Vpc, CidrBlock: 10.10.2.0/24, AvailabilityZone: !Select [1, !GetAZs ""] }

  DbSubnetGroup:
    Type: AWS::RDS::DBSubnetGroup
    Properties: { DBSubnetGroupDescription: private db subnets, SubnetIds: [!Ref SubnetA, !Ref SubnetB] }

  ApiSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties: { GroupDescription: api egress only, VpcId: !Ref Vpc }
  DbSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: postgres from api only
      VpcId: !Ref Vpc
      SecurityGroupIngress:
        - { IpProtocol: tcp, FromPort: 5432, ToPort: 5432, SourceSecurityGroupId: !Ref ApiSecurityGroup }

  DbPassword:                                   # generated, never in the template or a parameter
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: !Sub two-tier/${Env}/db-password
      GenerateSecretString: { PasswordLength: 32, ExcludePunctuation: true }

  Db:
    Type: AWS::RDS::DBInstance
    DeletionPolicy: !If [IsProd, Snapshot, Delete]
    UpdateReplacePolicy: Snapshot
    Properties:
      Engine: postgres
      EngineVersion: "16"
      DBInstanceClass: !Ref DbClass
      AllocatedStorage: 20
      DBName: app
      MasterUsername: app
      MasterUserPassword: !Sub "{{resolve:secretsmanager:${DbPassword}:SecretString}}"
      DBSubnetGroupName: !Ref DbSubnetGroup
      VPCSecurityGroups: [!Ref DbSecurityGroup]
      PubliclyAccessible: false
      StorageEncrypted: true
      MultiAZ: !If [IsProd, true, false]
      BackupRetentionPeriod: !If [IsProd, 14, 1]
      DeletionProtection: !If [IsProd, true, false]

  ApiRole:                                      # what the running container may do: read one secret
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Statement: [{ Effect: Allow, Principal: { Service: tasks.apprunner.amazonaws.com }, Action: sts:AssumeRole }]
      Policies:
        - PolicyName: read-db-secret
          PolicyDocument:
            Statement: [{ Effect: Allow, Action: secretsmanager:GetSecretValue, Resource: !Ref DbPassword }]
  EcrAccessRole:                                # what App Runner may do on your behalf: pull the image
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Statement: [{ Effect: Allow, Principal: { Service: build.apprunner.amazonaws.com }, Action: sts:AssumeRole }]
      ManagedPolicyArns: [arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess]

  VpcConnector:
    Type: AWS::AppRunner::VpcConnector
    Properties: { Subnets: [!Ref SubnetA, !Ref SubnetB], SecurityGroups: [!Ref ApiSecurityGroup] }

  Api:
    Type: AWS::AppRunner::Service
    Properties:
      ServiceName: !Sub two-tier-api-${Env}
      SourceConfiguration:
        AuthenticationConfiguration: { AccessRoleArn: !GetAtt EcrAccessRole.Arn }
        AutoDeploymentsEnabled: false
        ImageRepository:
          ImageIdentifier: !Ref ImageUri
          ImageRepositoryType: ECR
          ImageConfiguration:
            Port: "8080"
            RuntimeEnvironmentVariables:
              - { Name: DB_HOST, Value: !GetAtt Db.Endpoint.Address }
              - { Name: DB_USER, Value: app }
              - { Name: DB_NAME, Value: app }
            RuntimeEnvironmentSecrets:
              - { Name: DB_PASSWORD, Value: !Ref DbPassword }
      InstanceConfiguration: { Cpu: "0.25 vCPU", Memory: "0.5 GB", InstanceRoleArn: !GetAtt ApiRole.Arn }
      NetworkConfiguration:
        EgressConfiguration: { EgressType: VPC, VpcConnectorArn: !GetAtt VpcConnector.VpcConnectorArn }
      HealthCheckConfiguration: { Protocol: HTTP, Path: /healthz/ready }

Outputs:
  ApiUrl: { Value: !Sub "https://${Api.ServiceUrl}" }
  DbEndpoint: { Value: !GetAtt Db.Endpoint.Address }
```

**Lab 1b.3 (45 min): deploy it, change it, break it, roll it back**

```bash
aws cloudformation validate-template --template-body file://infra-aws/two-tier.yaml
cfn-lint infra-aws/two-tier.yaml                      # pip install cfn-lint

# first deploy: --deploy with change sets under the hood
aws cloudformation deploy --stack-name two-tier-staging --template-file infra-aws/two-tier.yaml \
  --parameter-overrides Env=staging ImageUri=ACCOUNT.dkr.ecr.REGION.amazonaws.com/api@sha256:DIGEST \
  --capabilities CAPABILITY_IAM
aws cloudformation describe-stacks --stack-name two-tier-staging --query 'Stacks[0].Outputs'

# preview a change the way a PR would: a change set you can read before executing
aws cloudformation create-change-set --stack-name two-tier-staging --change-set-name bigger-db \
  --template-body file://infra-aws/two-tier.yaml --capabilities CAPABILITY_IAM \
  --parameters ParameterKey=Env,ParameterValue=staging ParameterKey=DbClass,ParameterValue=db.t4g.small \
               ParameterKey=ImageUri,UsePreviousValue=true
aws cloudformation describe-change-set --stack-name two-tier-staging --change-set-name bigger-db \
  --query 'Changes[].ResourceChange.[Action,LogicalResourceId,Replacement]'   # look for Replacement=True
aws cloudformation execute-change-set --stack-name two-tier-staging --change-set-name bigger-db

# drift: change the DB security group in the console, then
aws cloudformation detect-stack-drift --stack-name two-tier-staging
aws cloudformation describe-stack-resource-drifts --stack-name two-tier-staging --query 'StackResourceDrifts[?StackResourceDriftStatus!=`IN_SYNC`]'

# rollback: push a template with a typo in ImageUri and watch CloudFormation revert the whole stack
aws cloudformation describe-stack-events --stack-name two-tier-staging --max-items 20

# cleanup (staging has DeletionPolicy Delete; prod would snapshot and refuse until DeletionProtection is off)
aws cloudformation delete-stack --stack-name two-tier-staging && aws cloudformation wait stack-delete-complete --stack-name two-tier-staging
```

**Choosing between them.** All-in on AWS with a platform team that wants native guardrails (StackSets across an Organization, service roles, Config rules): CloudFormation or CDK. Multi-cloud, or GKE plus anything else, or a team that already knows HCL: Terraform. Many AWS shops run both: Terraform for the account skeleton, CDK for application stacks. Whichever you pick, the rule from Part B holds: every resource in code, the console read-only, changes through pull requests with a plan or change set attached.

**Part D: Security implications**

Each step right on the compute spectrum hands a layer to the provider and removes a class of mistakes you can make; each IaC tool adds a new artifact (state, templates, pipeline credentials) that becomes a target. The security story is therefore two tables: what you still have to defend at each compute tier, and what IaC itself introduces.

**D1. The shared-responsibility line moves with the compute tier**

| Tier | Provider now covers | Still yours | The mistake interviewers have seen |
| --- | --- | --- | --- |
| VMs | Hypervisor, physical hosts | OS patching, SSH keys, host firewall, agents, disk encryption settings, the instance's service account scope | Default service account with Editor on every VM; port 22 open to 0.0.0.0/0; unpatched image from two years ago |
| Managed Kubernetes | Control plane, etcd, API server patching | Node image patching cadence, RBAC, Pod Security, NetworkPolicy, workload identity, add-ons | Public control plane endpoint with no authorized networks; pods running as root; a Secret readable by every namespace |
| Autopilot / Fargate | Nodes too | Workloads, RBAC, NetworkPolicy, images | Assuming "serverless nodes" means no image scanning needed |
| Cloud Run / App Runner / Lambda | Everything below the container or function | Code, dependencies, IAM role of the service, ingress setting, secrets wiring | `allUsers` invoker on an internal service; over-broad service role; secret pasted as a plain env var |

Across all tiers, three things never move to the provider: identity (who or what can call what), data (encryption keys, who can read the bucket or the database), and your code's dependencies.

**D2. Identity and the metadata server.** Every VM and pod can reach a metadata endpoint (`169.254.169.254`) that hands out credentials for the machine's service account. On a VM, a server-side request forgery bug in your app is enough for an attacker to fetch those tokens. Controls, in the order you would apply them: a dedicated minimal service account per workload instead of the project default; IMDSv2 on AWS and GKE metadata concealment / Workload Identity on Google so pods get their own identity rather than the node's; and NetworkPolicy or egress rules so only the processes that need the metadata server can reach it. Lab 6.1 verified this from inside a pod.

**D3. Risks that infrastructure as code introduces, and the control for each**

| Risk | What goes wrong | Control |
| --- | --- | --- |
| State contains secrets | Terraform state holds DB passwords, keys, and every attribute in plaintext | Remote backend with encryption and tight IAM, versioning on, never committed to Git; prefer resources that generate secrets server-side (`GenerateSecretString`, `random_password` written straight to a secret store) over passing them as variables |
| Pipeline credentials | The CI job that runs `apply` is as powerful as Owner | OIDC federation (Module 5) instead of long-lived keys; a dedicated deployer identity per environment; CloudFormation service roles so humans only need `cloudformation:*` |
| Who can run apply | One PR merge changes production | Branch protection, required review, `plan` posted to the PR, `apply` only from `main` and only via the pipeline; separate state and separate identity per environment |
| Misconfiguration at scale | One wrong default replicated to 40 buckets | Static policy checks in CI: `tfsec` / `trivy config` / Checkov for Terraform, `cfn-lint` + `cfn_nag` or `cfn-guard` for CloudFormation, OPA / Sentinel for custom rules. Fail the build on a public bucket or a `0.0.0.0/0` ingress |
| Drift | Someone fixes an incident in the console; the next apply reverts it, or it never gets back into code | Scheduled `plan` / `detect-stack-drift` with alerts; console write access limited to a break-glass role; post-incident rule that every manual change becomes a PR |
| Supply chain of the tooling | A malicious or compromised provider, module, or GitHub Action | Pin provider and module versions and verify checksums (`.terraform.lock.hcl` committed); pull modules from a private registry; pin Actions by SHA; CloudFormation modules and CDK constructs from your own registry |
| Destructive changes | A plan with `-/+` on the database, approved at 5pm | `prevent_destroy` lifecycle rule, `deletion_protection`, \`DeletionPolicy: Retain |
| Secrets in templates | A password in `.tfvars` or a CloudFormation parameter in the pipeline logs | `sensitive = true` variables, `NoEcho: true` parameters, dynamic references to Secrets Manager / SSM, secret scanning on the repo (gitleaks, GitHub secret scanning) |
| Over-permissioned resources defined in code | The code itself grants `*:*` because it was quicker | Review IAM in PRs like you review code; IAM Access Analyzer / Policy Analyzer / Recommender to shrink roles from observed usage |

**D4. Encryption and keys, briefly.** Disks, databases, and object storage are encrypted at rest by default on all three clouds with provider-managed keys. Customer-managed keys (Cloud KMS, AWS KMS, Key Vault) add revocation and audit; they are the usual compliance ask and are one line in IaC (`disk_encryption_key`, `KmsKeyId`, `StorageEncrypted: true`). TLS in transit is the load balancer's job at the edge (Module 4's managed certificate) and a service mesh's job inside the cluster.

**D5. Audit.** Cloud Audit Logs / CloudTrail / Activity Log record every API call, including the ones Terraform and CloudFormation make. Two queries to be able to describe: "who changed this security group last Tuesday" and "which identity created resources outside the pipeline." The second is your drift and shadow-IT detector.

**Lab 1b.4 (30 min): put the checks in the pipeline**

```bash
# Terraform
pip install checkov && checkov -d infra-gcp/                    # misconfig scan; expect findings on the staging DB
trivy config infra-gcp/                                          # same idea, different ruleset
terraform plan -var-file envs/staging.tfvars -out p.tfplan && terraform show -json p.tfplan > plan.json
checkov -f plan.json                                         # scan the plan, which catches computed values

# CloudFormation
cfn-lint infra-aws/two-tier.yaml
pip install cfn-guard  # or brew install cloudformation-guard
cfn-guard validate --data infra-aws/two-tier.yaml --rules rules/no-public-db.guard

# the repo itself
pip install gitleaks || brew install gitleaks
gitleaks detect --source . --verbose
```

Add the three commands to the GitHub Actions workflow from Lab 5.1 as a `policy` job that must pass before `plan`, and you have the answer to "how do you keep infrastructure changes safe" as working code in your repo.

**Interview questions this module answers**

- VM, container, or serverless for this workload? (Workload first: stateless HTTP with a managed DB fits Cloud Run / App Runner; many services, sidecars, or custom networking fit Kubernetes; custom kernels, GPUs, or legacy agents fit VMs. Then team: who will patch nodes at 2am?)
- What is the shared responsibility model, and how does it change between EC2 and Lambda? (Provider always owns the physical layer and hypervisor; on VMs you own the OS up; on managed Kubernetes you own nodes and workloads; on serverless you own code, dependencies, and IAM. Identity and data never move.)
- Why infrastructure as code? (Review, history, repeatability, rebuild from zero, drift detection, and the console becomes read-only. Same reasons you version application code.)
- Terraform state: what is in it and how do you protect it? (Resource-to-ID mapping plus every attribute, secrets included, in plaintext. Remote encrypted backend, locking, versioning, tight IAM, never in Git; generate secrets server-side so they do not pass through state as inputs.)
- Terraform versus CloudFormation? (Multi-cloud HCL with a state file you manage, versus AWS-native templates with service-held state, automatic rollback, change sets, and StackSets. Pick by cloud footprint and team; many run both.)
- What is a change set and why use it? (A CloudFormation preview of exactly what an update will do, including which resources are replaced. It is the equivalent of reviewing `terraform plan` before `apply`.)
- How do you prevent a destructive infrastructure change? (Read the plan for `-/+` or `Replacement: True`; `prevent_destroy`, `deletion_protection`, `DeletionPolicy: Snapshot`; required reviewers; apply only from the pipeline.)
- What is drift and how do you handle it? (Reality diverged from code, usually a console change during an incident. Detect with scheduled plan or drift detection, restrict console writes to a break-glass role, and make every manual fix a follow-up PR.)
- How do you secure the pipeline that applies infrastructure? (OIDC instead of static keys; one deployer identity per environment; plan on PR, apply on merge; policy-as-code gates; pinned providers, modules, and Actions; secret scanning.)
- What is the metadata server risk? (Any process on a VM or pod can ask `169.254.169.254` for the machine's credentials; an SSRF bug in your app leaks them. Minimal per-workload identities, IMDSv2 / Workload Identity, and egress rules.)
- How would you do policy as code for infrastructure? (Checkov / tfsec / trivy config for Terraform, cfn-lint and cfn-guard for CloudFormation, OPA or Sentinel for custom rules; run them in CI and fail the build; add org-level guardrails such as Org Policy constraints or SCPs so the rule holds even outside the pipeline.)
