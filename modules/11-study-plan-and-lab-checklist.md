# 7-day study plan and lab checklist

Seven days at two to three hours each covers every lab once and leaves the last day for a full dry run. If you have less time, do days 2, 4, 5, and 6: those four labs produce the artifacts you can talk about in the room.

| Day | Focus | Labs | Done when you can say |
| --- | --- | --- | --- |
| 1 | Laptop first, then cloud foundations | Module 0 steps 1 to 5, Setup, Lab 1.1, Module 1b Parts A to B (Labs 1b.1, 1b.2) | "Here is the two-tier app on Cloud Run with a private DB, and here is what Kubernetes will add" |
| 2 | Containers | Labs 2.1, 2.2, 2.3 | "My image is distroless, non-root, scanned, and pushed by digest" |
| 3 | Kubernetes fundamentals | Labs 3.1, 3.2, Module 3b, Module 1b Parts C to D (Labs 1b.3, 1b.4) | "I can explain the control plane and I stood up a private regional GKE cluster with Terraform" |
| 4 | App on Kubernetes | Labs 4.1, 4.2, 4.3 | "Three replicas behind HTTPS, Workload Identity to Cloud SQL, PDB, HPA, packaged as a Helm chart with per-environment values and a digest guardrail" |
| 5 | CI/CD | Labs 5.1, 5.2 | "A commit becomes a signed image and a config-repo change; Argo CD syncs it; self-heal corrects drift" |
| 6 | Security | Labs 6.1 to 6.6 | "Restricted PSA, default-deny NetworkPolicy, least-privilege RBAC, external secrets, signed images enforced" |
| 7 | Wiz TAM lens, operations, and dry run | Module 8 Parts A to E, Labs 8.1 and 8.2, Lab 7.1, question bank | Deliver a 15-minute mock QBR for a fictional customer using the templates, then answer 15 random technical and 5 random TAM questions aloud in under two minutes each |

**Lab checklist**

- [ ] Module 0: API in one container, Compose with Postgres, two replicas on kind, distroless image built
- [ ] Lab 1.1: two tiers on Cloud Run and Cloud SQL, private IP, secret from Secret Manager
  - [ ] Lab 1b.1: API running on a plain VM under systemd; list of what you had to do by hand written down
  - [ ] Lab 1b.2: network, Cloud SQL, IAM, and GKE in Terraform with remote state; drift and destructive-change experiments done
  - [ ] Lab 1b.3: CloudFormation stack deployed, change set read, drift detected, rollback observed, stack deleted
  - [ ] Lab 1b.4: Checkov / cfn-lint / gitleaks running in CI as a policy job
- [ ] Lab 8.1: toxic combination built, proven from inside the pod, and broken link by link; four-line customer write-up done
- [ ] Lab 8.2: Prowler / kube-bench / trivy k8s / checkov findings triaged to a top five by exposure, privilege, data
- [ ] Module 8 templates filled in for one fictional customer and a 15-minute mock QBR delivered aloud
- [ ] Lab 2.1: multi-stage distroless Dockerfile, non-root
- [ ] Lab 2.2: Docker Compose two-tier running locally
- [ ] Lab 2.3: image pushed to Artifact Registry, Trivy report read, digest recorded
- [ ] Lab 3.1: kind cluster, Deployment scale / rollout / undo narrated by controller
- [ ] Lab 3.2: private regional GKE cluster from Terraform, Workload Identity enabled
- [ ] Lab 4.1: full manifest set applied, managed certificate Active, HTTPS endpoint works
- [ ] Lab 4.2: Postgres StatefulSet deployed and deleted; argument for managed DB written down
- [ ] Lab 4.3: charts/api linted and templated; staging release installed with --atomic; helm test passed; a failed upgrade rolled back with helm rollback; one third-party chart installed with a pinned version
- [ ] Lab 5.1: GitHub Actions pipeline green with OIDC auth, scan gate, cosign signature
- [ ] Lab 5.2: Argo CD syncing from config repo; self-heal demonstrated
- [ ] Lab 6.1: Workload Identity verified from inside the pod; 403 on unbound secret
- [ ] Lab 6.2: Role and RoleBinding tested with `kubectl auth can-i`
- [ ] Lab 6.3: restricted PSA rejects a root pod; Kyverno registry policy enforced
- [ ] Lab 6.4: default-deny NetworkPolicy applied, DNS and DB allowed back
- [ ] Lab 6.5: External Secrets Operator or CSI driver pulling from Secret Manager
- [ ] Lab 6.6: unsigned image rejected by Binary Authorization or Kyverno verifyImages
- [ ] Lab 7.1: OOMKilled, failed readiness, node drain with PDB, broken identity binding all observed and fixed
- [ ] teardown.sh run at the end of each day; verification list came back empty

**What to bring to the interview**

A public GitHub repo with the app, Dockerfile, Terraform and CloudFormation, Kubernetes manifests or Helm chart, the Actions workflow, and a README with the architecture diagram from Module 1; plus the filled-in success plan and QBR deck from Module 8 for the TAM rounds. Interviewers who can click through a working pipeline ask easier questions.

**Sources**

- [Kubernetes documentation](https://kubernetes.io/docs/) (concepts, Pod Security Standards, NetworkPolicy)
- [GKE documentation](https://cloud.google.com/kubernetes-engine/docs) (private clusters, Workload Identity, Binary Authorization)
- [Argo CD documentation](https://argo-cd.readthedocs.io/)
- [Sigstore cosign](https://docs.sigstore.dev/) and [Trivy](https://aquasecurity.github.io/trivy/)
- [CNCF Cloud Native Security Whitepaper](https://www.cncf.io/reports/cloud-native-security-whitepaper/) (the 4Cs model)

Version numbers and CLI flags in the labs reflect what was current when this was written; check the linked docs before copying commands into a real project.
