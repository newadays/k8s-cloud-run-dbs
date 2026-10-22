# Module 6: Cloud native security

Organize every security answer around the 4Cs: Cloud, Cluster, Container, Code. Each layer only protects against what the layers outside it have not already let through, so you harden from the outside in and assume each layer will eventually fail.

| Layer | What you control | Lab controls (GKE) | Equivalents |
| --- | --- | --- | --- |
| Cloud | IAM, network, control plane exposure, audit logs | Private nodes, authorized networks, dedicated node SA, Cloud Audit Logs, Org Policy | AWS IAM + SCPs + CloudTrail; Azure RBAC + Policy + Activity Log |
| Cluster | Who can do what inside the API, what can run, what can talk | RBAC, Pod Security Admission, NetworkPolicy, Policy Controller, Binary Authorization | Gatekeeper/Kyverno, EKS Pod Identity, Azure Policy for AKS |
| Container | Image contents, runtime privileges | Distroless, non-root, read-only FS, dropped capabilities, seccomp, image scanning, cosign verification | ECR scanning, Defender for Containers |
| Code | Dependencies, secrets, app vulnerabilities | pip-audit, Dependabot, secret scanning, SBOM | Same tooling |

**Lab 6.1 (20 min): IAM and Workload Identity, least privilege**

1. List what the default compute service account can do: `gcloud projects get-iam-policy PROJECT --flatten=bindings[].members --filter="bindings.members:compute@developer"`. It is usually Editor. That is the first thing a reviewer flags.
2. Confirm your node pool uses the dedicated `nodes` SA with only `logging.logWriter`, `monitoring.metricWriter`, `artifactregistry.reader`.
3. From inside the `api` pod, `curl -H 'Metadata-Flavor: Google' http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/email` and confirm it returns `api-sa`, not the node SA. That is Workload Identity working: the pod's identity is its own, scoped to its namespace and KSA.
4. Try to read a secret the SA is not bound to and confirm the 403. Interview phrase: "identity per workload, no key files, verify by trying to exceed it."

**Lab 6.2 (30 min): RBAC**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: { name: deployer, namespace: two-tier }
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "patch", "update"]
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: deployer, namespace: two-tier }
subjects:
  - kind: User
    name: dev@example.com
roleRef: { kind: Role, name: deployer, apiGroup: rbac.authorization.k8s.io }
```

Test with `kubectl auth can-i delete deployments -n two-tier --as dev@example.com` (expect no) and `kubectl auth can-i patch deployments -n two-tier --as dev@example.com` (expect yes). Rules of thumb: Role over ClusterRole, bind groups not users, never bind `cluster-admin` to a service account, audit with `kubectl get clusterrolebindings -o wide`.

**Lab 6.3 (30 min): Pod Security Admission and admission policy**

Label the namespace so non-compliant pods are rejected: `kubectl label ns two-tier pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/warn=restricted`. Try to deploy a pod that runs as root or mounts the host path and read the rejection. The `restricted` profile is why Module 4's Deployment set `runAsNonRoot`, `allowPrivilegeEscalation: false`, dropped all capabilities, and `seccompProfile: RuntimeDefault`.

For policies PSA cannot express (require labels, block `latest` tags, require resource limits, allow only your registry), install Kyverno or Gatekeeper. One Kyverno policy to try:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata: { name: allowed-registry }
spec:
  validationFailureAction: Enforce
  rules:
    - name: only-our-registry
      match: { any: [{ resources: { kinds: [Pod] } }] }
      validate:
        message: "Images must come from us-central1-docker.pkg.dev/PROJECT/"
        pattern:
          spec:
            containers:
              - image: "us-central1-docker.pkg.dev/PROJECT/*"
```

**Lab 6.4 (30 min): NetworkPolicy, default deny**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny, namespace: two-tier }
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: api-allow, namespace: two-tier }
spec:
  podSelector: { matchLabels: { app: api } }
  policyTypes: [Ingress, Egress]
  ingress:
    - from:
        - ipBlock: { cidr: 130.211.0.0/22 }   # GCLB health checks / proxies
        - ipBlock: { cidr: 35.191.0.0/16 }
      ports: [{ port: 8080 }]
  egress:
    - to: [{ ipBlock: { cidr: 10.0.0.0/8 } }]  # Cloud SQL private IP range
      ports: [{ port: 5432 }]
    - to:
        - namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: kube-system } }
      ports: [{ port: 53, protocol: UDP }, { port: 53, protocol: TCP }]
```

Apply the default-deny first and watch the API lose DNS; then apply the allow policy and watch it recover. NetworkPolicy needs a CNI that enforces it (GKE Dataplane V2 or Calico; on EKS enable the network policy feature or install Calico/Cilium). Mention that a service mesh (Istio, Anthos Service Mesh, Linkerd) adds mTLS and L7 authorization on top.

**Lab 6.5 (20 min): secrets done properly**

Kubernetes Secrets are base64 in etcd; by default anyone with `get secrets` reads them in plaintext. Three improvements, in order of effort:

1. Enable envelope encryption of etcd with a KMS key (`--database-encryption-key` on GKE; EKS secrets encryption; AKS KMS plugin).
2. Keep the source of truth outside the cluster: External Secrets Operator syncing from Secret Manager into Kubernetes Secrets, with the sync identity using Workload Identity. Rotation becomes a Secret Manager version bump.
3. Skip Kubernetes Secrets entirely for the hottest credentials: the Secrets Store CSI driver mounts Secret Manager values as files, or the app calls the secret API directly at startup.

**Lab 6.6 (20 min): supply chain, from scan to enforcement**

The pipeline in Module 5 already signs with cosign and attaches an SBOM. Close the loop with Binary Authorization (or a Kyverno `verifyImages` rule) so the cluster rejects any image that is not signed by your CI identity. Deploy an unsigned image and read the admission failure. Vocabulary: SLSA levels, provenance attestations, SBOM (SPDX/CycloneDX), Sigstore (cosign, Fulcio, Rekor).

**Runtime and detection (know the names, deploy one if time allows)**

- Falco or GKE Security Posture / Container Threat Detection: alerts on shell spawned in a container, unexpected outbound connections, file writes to `/bin`.
- Audit logs: who ran `kubectl exec`, who read a secret. Ship API server audit logs to Cloud Logging / CloudTrail / Log Analytics.
- CIS Kubernetes Benchmark with `kube-bench`; GKE Security Posture dashboard reports the same findings.

**Interview questions this module answers**

- How do you secure a Kubernetes cluster? (4Cs from outside in: private control plane and least-privilege IAM; RBAC, PSA, NetworkPolicy, admission policy; hardened images with scanning and signing; dependency and secret hygiene in code. End with detection and audit logs.)
- How does a pod get cloud credentials without a key file? (Workload Identity: KSA annotated to a cloud SA, token exchange via the metadata server or projected token; IRSA/Pod Identity on EKS.)
- A container was compromised. What limits the blast radius? (Non-root, read-only FS, dropped capabilities, seccomp, NetworkPolicy default deny, namespace-scoped RBAC, Workload Identity scoped to that KSA, no host mounts.)
- Are Kubernetes Secrets secure? (Not by default; explain etcd encryption, RBAC on secrets, external secret stores, and rotation.)
- How do you stop an unapproved image reaching production? (Scan and sign in CI, admission control verifies the signature and registry, policy fails closed.)
- Difference between RBAC and IAM here? (IAM gates who can reach the cluster API and what cloud resources workloads can touch; RBAC gates what they can do inside the Kubernetes API once there. Both are needed.)
