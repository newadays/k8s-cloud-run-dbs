# How to use this course

The interview tests four technical things: deploy a two-tier app to the cloud, stand up Kubernetes clusters, build CI/CD pipelines, and configure cloud-native security. The target role is the Wiz Technical Account Manager (Mid-Atlantic) posting, so Module 8 adds the product and CNAPP vocabulary, cloud threat models, and the customer-facing TAM motion that posting also asks for. Module 0 starts on your laptop with one container and one web service, and every later module reuses that same code and image; each module pairs a short concept brief with a lab you run yourself and the interview questions that lab answers. Do the labs; interviewers can tell the difference between someone who has read about `kubectl rollout` and someone who has watched one fail.

The labs use Google Cloud (GKE, Artifact Registry, Cloud Build) as the primary platform, with the AWS and Azure equivalents named at every step so you can answer for whichever cloud the interviewer uses. The example app is a Python Flask API (tier 1) backed by PostgreSQL (tier 2), small enough to deploy in an afternoon and realistic enough to discuss trade-offs.

**Lab setup (do this once, about 30 minutes)**

- [ ] Google Cloud project with billing enabled, plus `gcloud` CLI installed and authenticated (`gcloud auth login`, `gcloud config set project PROJECT_ID`)
- [ ] Enable APIs: `gcloud services enable container.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com`
- [ ] Install `kubectl`, `helm`, `docker` (or Podman), `terraform`, and `trivy`
- [ ] A GitHub account and an empty repo named `two-tier-app`
- [ ] Optional: `kind` or `minikube` for a free local cluster to practice manifests before paying for GKE

| Concept | Google Cloud | AWS | Azure |
| --- | --- | --- | --- |
| Managed Kubernetes | GKE | EKS | AKS |
| Container registry | Artifact Registry | ECR | ACR |
| Managed PostgreSQL | Cloud SQL | RDS | Azure Database for PostgreSQL |
| Native CI/CD | Cloud Build / Cloud Deploy | CodeBuild / CodePipeline | Azure Pipelines |
| Secrets | Secret Manager | Secrets Manager / SSM | Key Vault |
| Pod-to-cloud identity | Workload Identity | IRSA / Pod Identity | Workload Identity |
| Image scanning | Artifact Analysis | ECR scanning (Inspector) | Defender for Containers |
| Admission policy | Policy Controller (Gatekeeper) | Gatekeeper / Kyverno | Azure Policy for AKS |

**Budget note:** a 3-node GKE Standard cluster on e2-medium costs roughly $0.30/hour plus the cluster fee (one zonal cluster per account is free of the management fee). Run the teardown script when you finish each day (see Teardown, after Module 7), or at minimum delete the cluster: `gcloud container clusters delete two-tier --zone us-central1-a`.
