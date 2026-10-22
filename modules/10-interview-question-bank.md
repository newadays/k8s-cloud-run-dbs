# Interview question bank and answer frameworks

Three frameworks cover almost every question in this interview. Pick the one that matches the question's shape, answer in under two minutes, then stop and let them dig.

**Framework A: the design walk ("how would you deploy / build / secure X")**

Compute, Data, Network, Identity, Delivery, Observability. Name your choice for each, one trade-off, and what you would change at 10x scale. Example for "deploy a two-tier app": GKE Standard regional cluster; Cloud SQL regional with private IP; VPC-native cluster with NetworkPolicy and a Cloud Load Balancer; Workload Identity per workload and a dedicated node SA; GitHub Actions to Artifact Registry to Argo CD; Managed Prometheus with SLO alerts. At 10x: read replicas and connection pooling, multi-region ingress, separate prod cluster.

**Framework B: the control loop ("what happens when / why is X broken")**

Desired state, observed state, which controller reconciles, what evidence shows the gap. Example for "pod is Pending": desired is 3 replicas; observed is 2 Running and 1 Pending; the scheduler is the controller; `kubectl describe pod` events show the reason (resources, taints, affinity, volume).

**Framework C: outside in ("how do you secure X")**

Cloud, Cluster, Container, Code, then detection. Two controls per layer, then "and if that fails" for the next layer.

**Question bank by round**

| Round | Question | Core of the answer |
| --- | --- | --- |
| Cloud | Shared responsibility model? | Provider secures the platform; you secure config, identity, data, and code |
| Cloud | Region vs zone, and how it shapes a design? | Zone is a failure domain; spread nodes and use a regional DB |
| Cloud | How do you manage infrastructure? | Terraform in Git, plan on PR, apply from CI with OIDC, state in a locked remote backend |
| Cloud | VM vs serverless vs Kubernetes for this app? | Cloud Run for a single stateless service; Kubernetes when you need many services, custom networking, or portability |
| Kubernetes | Deployment vs StatefulSet vs DaemonSet vs Job? | Stateless replicas / stable identity and storage / one per node / run to completion |
| Kubernetes | How does Service discovery work? | DNS name to ClusterIP; kube-proxy or eBPF programs node rules to pod IPs from Endpoints/EndpointSlices |
| Kubernetes | ClusterIP vs NodePort vs LoadBalancer vs Ingress? | Internal / node port on every node / cloud L4 LB / L7 routing and TLS |
| Kubernetes | Requests vs limits? | Requests schedule and reserve; limits cap; memory over limit is OOMKilled, CPU over limit is throttled |
| Kubernetes | How do probes differ? | Startup gates the others; readiness gates traffic; liveness restarts |
| Kubernetes | HPA vs VPA vs Cluster Autoscaler? | More pods / bigger pods / more nodes |
| Kubernetes | Namespaces for environments, or clusters? | Namespaces for cost and non-prod; separate cluster for prod blast radius |
| Kubernetes | Helm vs Kustomize? | Templated packages with values / overlays with patches; both can be driven by Argo |
| CI/CD | What makes a pipeline trustworthy? | Reproducible builds, tests, scanning, signing, least-privilege OIDC auth, protected branches |
| CI/CD | GitOps, and why? | Git is the desired state; a controller pulls and reconciles; audit, rollback, drift correction, no inbound creds |
| CI/CD | Canary release in Kubernetes? | Argo Rollouts or Gateway API traffic split, promote on SLO metrics, auto-rollback |
| CI/CD | How do you test infrastructure changes? | `terraform plan` on PR, policy checks (OPA/Checkov), apply to staging, smoke tests |
| CI/CD | Secrets in CI? | OIDC federation instead of keys; vault-backed secrets; masked logs; short-lived tokens |
| Security | Workload Identity / IRSA? | Pod identity maps a KSA to a cloud identity via token exchange; no key files |
| Security | RBAC best practices? | Namespace Roles, bind groups, no wildcards, no cluster-admin to SAs, audit regularly |
| Security | NetworkPolicy default deny: how do you roll it out? | Audit mode or staging first, allow DNS and health checks, then per-app allow rules |
| Security | Image hardening? | Distroless, non-root, read-only, drop caps, scan, sign, deploy by digest, admission verifies |
| Security | Pod Security Standards? | Privileged, baseline, restricted; enforce restricted in app namespaces via namespace labels |
| Security | How would you detect a breach? | Audit logs, Falco/Threat Detection, anomalous egress, alerts on exec and secret reads |
| Security | Encrypt data in transit and at rest? | TLS at the edge and mTLS via mesh; CMEK on disks, DB, and etcd |
| Behavioral | A deploy you broke and what you changed | Use STAR; end with the guardrail you added (PDB, canary, pre-deploy check) |
| Behavioral | Convincing a team to adopt GitOps / policy | Start with the incident it prevents; pilot on one service; show the audit trail |

**Tell-me-about-a-time prompts to prepare (STAR, 90 seconds each)**

- A production incident you diagnosed on Kubernetes and what you automated afterward.
- A security finding you fixed (over-permissive SA, public bucket, secret in a repo) and how you prevented recurrence.
- A pipeline you made faster or safer, with a number (minutes saved, failed deploys avoided).
- A trade-off you argued for and lost, and what you learned.
