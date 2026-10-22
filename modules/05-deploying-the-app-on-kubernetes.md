# Module 4: Deploying the two-tier app on Kubernetes

The app tier becomes a Deployment behind a Service and an Ingress; the data tier stays in Cloud SQL, reached through a sidecar proxy with Workload Identity. Every manifest below is one you should be able to write from memory in a whiteboard round.

**Lab 4.1 (60 min): the manifests**

Namespace, config, and the Kubernetes service account bound to a Google service account:

```yaml
apiVersion: v1
kind: Namespace
metadata: { name: two-tier }
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api
  namespace: two-tier
  annotations:
    iam.gke.io/gcp-service-account: api-sa@PROJECT.iam.gserviceaccount.com
---
apiVersion: v1
kind: ConfigMap
metadata: { name: api-config, namespace: two-tier }
data:
  DB_HOST: "127.0.0.1"      # Cloud SQL proxy sidecar
  DB_NAME: "app"
  LOG_LEVEL: "info"
```

Bind the identities once: `gcloud iam service-accounts add-iam-policy-binding api-sa@PROJECT.iam.gserviceaccount.com --role roles/iam.workloadIdentityUser --member "serviceAccount:PROJECT.svc.id.goog[two-tier/api]"` and give `api-sa` the `roles/cloudsql.client` and `roles/secretmanager.secretAccessor` roles.

The Deployment, with the probes, resources, and security context interviewers look for:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: api, namespace: two-tier }
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate: { maxSurge: 1, maxUnavailable: 0 }
  selector: { matchLabels: { app: api } }
  template:
    metadata: { labels: { app: api } }
    spec:
      serviceAccountName: api
      securityContext:
        runAsNonRoot: true
        seccompProfile: { type: RuntimeDefault }
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: ScheduleAnyway
          labelSelector: { matchLabels: { app: api } }
      containers:
        - name: api
          image: us-central1-docker.pkg.dev/PROJECT/apps/api@sha256:DIGEST
          ports: [{ containerPort: 8080 }]
          envFrom: [{ configMapRef: { name: api-config } }]
          env:
            - name: DB_PASSWORD
              valueFrom: { secretKeyRef: { name: db-credentials, key: password } }
          resources:
            requests: { cpu: 100m, memory: 128Mi }
            limits:   { memory: 256Mi }
          readinessProbe:
            httpGet: { path: /healthz/ready, port: 8080 }
            periodSeconds: 5
          livenessProbe:
            httpGet: { path: /healthz/live, port: 8080 }
            initialDelaySeconds: 10
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities: { drop: ["ALL"] }
        - name: cloud-sql-proxy
          image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:2.14.0
          args: ["--private-ip", "--port=5432", "PROJECT:us-central1:two-tier-db"]
          securityContext: { runAsNonRoot: true }
          resources: { requests: { cpu: 50m, memory: 64Mi } }
```

Service, Ingress with a managed certificate, PodDisruptionBudget, and autoscaler:

```yaml
apiVersion: v1
kind: Service
metadata: { name: api, namespace: two-tier }
spec:
  selector: { app: api }
  ports: [{ port: 80, targetPort: 8080 }]
---
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata: { name: api-cert, namespace: two-tier }
spec: { domains: [api.example.com] }
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api
  namespace: two-tier
  annotations:
    kubernetes.io/ingress.class: "gce"
    networking.gke.io/managed-certificates: api-cert
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend: { service: { name: api, port: { number: 80 } } }
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: { name: api, namespace: two-tier }
spec:
  minAvailable: 2
  selector: { matchLabels: { app: api } }
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: { name: api, namespace: two-tier }
spec:
  scaleTargetRef: { apiVersion: apps/v1, kind: Deployment, name: api }
  minReplicas: 3
  maxReplicas: 10
  metrics:
    - type: Resource
      resource: { name: cpu, target: { type: Utilization, averageUtilization: 60 } }
```

Apply with `kubectl apply -f k8s/`, then `kubectl -n two-tier get pods,svc,ingress` and wait for the load balancer IP. Point DNS at it and watch the managed certificate go Active (10 to 20 minutes).

**Why each object exists (the interview version)**

| Object | One-line purpose | The follow-up you will get |
| --- | --- | --- |
| Deployment | Declares replicas and rollout strategy; owns ReplicaSets | "maxSurge 1 / maxUnavailable 0 means never fewer than 3 serving during a rollout" |
| Service (ClusterIP) | Stable virtual IP and DNS name over a changing set of pods | "ClusterIP vs NodePort vs LoadBalancer vs headless" |
| Ingress / Gateway API | L7 routing and TLS from one external IP to many services | "Gateway API is the successor; know it exists" |
| ConfigMap vs Secret | Non-sensitive config vs base64 values stored (by default) unencrypted in etcd | "Secrets are not encrypted at rest unless you enable it; use an external store" |
| Readiness vs liveness | Readiness gates traffic; liveness restarts the container | "A bad liveness probe causes restart storms; readiness is the safer one" |
| Requests vs limits | Requests drive scheduling; limits drive throttling/OOM | "Set memory limits, be careful with CPU limits (throttling)" |
| PDB | Caps voluntary disruption during node drains | "Without it a cluster upgrade can take down every replica" |
| HPA | Scales replicas on metrics | "HPA scales pods; Cluster Autoscaler scales nodes; VPA right-sizes requests" |

**Lab 4.2 (30 min): run Postgres in the cluster, so you can argue against it**

Deploy a `StatefulSet` with a `volumeClaimTemplate` on the `standard-rwo` StorageClass and a headless Service. Then delete the pod and confirm the data survives; delete the PVC and confirm it does not. You now have first-hand reasons for the StatefulSet vs managed-database answer: stable network identity and ordered startup are solved, but backups, failover, minor-version upgrades, and connection pooling are still yours.

**Lab 4.3 (60 min): package it with Helm**

Helm is the package manager for Kubernetes: a *chart* is a folder of templated manifests plus default values; a *release* is one installed instance of a chart in a namespace, with a numbered revision history you can roll back through. Teams use it for two different jobs, and interviewers ask about both: consuming third-party software (`helm install` of ingress-nginx, Argo CD, Prometheus, External Secrets) and packaging their own services so one chart deploys to staging and prod with different values. The course repo has a finished chart in `charts/api/`; this lab walks through it rather than starting from `helm create`.

| Concept | What it is | In `charts/api/` |
| --- | --- | --- |
| `Chart.yaml` | Name, chart `version` (bump when templates change), `appVersion` (the image tag the chart deploys by default) | `version: 0.1.0`, `appVersion: "0.2.0"` |
| `values.yaml` | Every knob with a sane default; the documented interface of the chart | replicas, image, probes, resources, toggles for ingress/HPA/PDB/NetworkPolicy |
| `values-<env>.yaml` | Overrides per environment, passed with `-f`; later files win | staging: 2 replicas, no HPA; prod: 3 replicas, HPA on, larger requests, PDB minAvailable 2 |
| `templates/*.yaml` | Go templates that render to manifests; `{{ .Values.x }}`, `{{ .Release.Name }}`, `{{ .Chart.AppVersion }}` | one file per Kubernetes object |
| `_helpers.tpl` | Named template snippets reused across files | labels, selector labels, the image reference, a digest guardrail |
| `NOTES.txt` | Printed after install | the port-forward or Ingress command to try next |
| `templates/tests/` | Pods run by `helm test` | a curl against `/healthz/ready` |
| Hooks | Jobs run before or after install/upgrade (`helm.sh/hook: pre-upgrade`) | where a database migration Job would go |
| Release and revisions | Stored as Secrets in the namespace; `helm history` lists them, `helm rollback` restores one | every `upgrade` is a new revision |

Three patterns in the chart worth being able to explain:

```yaml
# _helpers.tpl: digest wins over tag; tag falls back to appVersion
{{- define "api.image" -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository (default .Chart.AppVersion .Values.image.tag) -}}
{{- end -}}
{{- end -}}

# _helpers.tpl: a guardrail that fails the render, not the cluster
{{- if and (eq .Release.Namespace "two-tier-prod") (not .Values.image.digest) -}}
{{- fail "image.digest is required for releases into two-tier-prod" -}}
{{- end -}}

# deployment.yaml: roll pods when the ConfigMap changes (envFrom alone does not)
annotations:
  checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

**Run it**

```bash
helm lint charts/api -f charts/api/values-staging.yaml
helm template api charts/api -f charts/api/values-staging.yaml > /tmp/rendered.yaml   # read it; this is what will be applied
helm template api charts/api -f charts/api/values-prod.yaml --namespace two-tier-prod   # fails: digest required

kubectl create namespace two-tier-staging
kubectl -n two-tier-staging create secret generic db-credentials \
  --from-literal=password="$(gcloud secrets versions access latest --secret db-password)"
helm upgrade --install api charts/api -n two-tier-staging -f charts/api/values-staging.yaml \
  --set image.digest=sha256:DIGEST --atomic --timeout 5m        # --atomic rolls back by itself if pods never become Ready
helm -n two-tier-staging test api
helm -n two-tier-staging list
helm -n two-tier-staging history api

# a bad release, then a rollback
helm upgrade api charts/api -n two-tier-staging -f charts/api/values-staging.yaml --set image.digest=sha256:0000 --timeout 90s
helm -n two-tier-staging history api                              # revision 2 failed
helm -n two-tier-staging rollback api 1 && helm -n two-tier-staging status api

# what helm actually stores
kubectl -n two-tier-staging get secrets -l owner=helm
helm -n two-tier-staging get values api                           # the values that produced this revision
helm -n two-tier-staging get manifest api | head -40
```

**Consuming charts: the other half**

```bash
helm repo add external-secrets https://charts.external-secrets.io && helm repo update
helm show values external-secrets/external-secrets | less          # read before you install anything
helm upgrade --install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace --version 0.10.5 \
  --set serviceAccount.annotations."iam\.gke\.io/gcp-service-account"=eso-sa@PROJECT.iam.gserviceaccount.com
helm -n external-secrets list
```

Pin the `--version`, read `show values` first, and keep your overrides in a committed values file rather than `--set` flags, so the install is reproducible. OCI registries work too: `helm pull oci://registry-1.docker.io/bitnamicharts/postgresql --version 16.0.0`.

**Helm and GitOps.** Argo CD renders charts itself: point an `Application` at `charts/api` with `helm.valueFiles: [values-prod.yaml]` and `helm.parameters` for the digest, and Argo does the `helm template` and the apply. Nothing in the cluster is then "a Helm release" (no `helm list`), but the chart stays the packaging format. Module 5's pipeline can promote by committing a new digest to the values file instead of a Kustomize overlay.

**Helm vs Kustomize.** Helm: templating, a values interface, versioned packages, hooks, rollback, the whole third-party ecosystem; cost is Go-template complexity. Kustomize: no templating, a base plus overlay patches, built into `kubectl`; cost is that it cannot express logic or ship as a package. Common answer: Helm for anything you distribute or install from others, Kustomize for last-mile patches on top, and Argo CD can render either (or Helm through Kustomize).

**Interview questions this lab answers**

- What is a Helm release and where is it stored? (A named install of a chart in a namespace; each revision is a Secret with the rendered manifest and values, which is what `rollback` restores.)
- How do you deploy the same chart to staging and prod? (One chart, per-environment values files, release per namespace; secrets come from the cluster, never from values.)
- `helm upgrade --install` vs `kubectl apply`? (Helm tracks ownership and history, computes a three-way merge, can run hooks and tests, and can roll back atomically.)
- How do you run a DB migration with Helm? (A Job with `helm.sh/hook: pre-upgrade` and `hook-delete-policy`, backward-compatible migrations only.)
- Why does changing a ConfigMap not restart pods, and what do you do? (Pod spec did not change; add a checksum annotation of the ConfigMap to the pod template.)
- What goes wrong with Helm at scale? (Chart sprawl, unpinned versions, values drift between environments, `--set` flags nobody recorded, CRDs that Helm will not upgrade; the fixes are a chart registry, pinned versions, committed values, and GitOps.)

**Interview questions this module answers**

- Walk me through what happens between `kubectl apply` and traffic arriving. (API server validates and stores; Deployment controller creates a ReplicaSet; it creates Pods; scheduler assigns nodes; kubelet pulls images and starts containers; readiness passes; endpoints controller adds pod IPs to the Service; Ingress controller programs the load balancer.)
- How do you do a zero-downtime deploy? (Rolling update with maxUnavailable 0, readiness probes that reflect real readiness, PDB, graceful shutdown handling SIGTERM with a preStop sleep, connection draining at the load balancer.)
- Blue/green vs canary vs rolling? (Rolling: default, gradual replacement. Blue/green: two full stacks, instant switch, double cost. Canary: small percentage first, needs traffic splitting via a service mesh, Gateway API, or Argo Rollouts/Flagger.)
- How does a pod talk to a managed database securely? (Private IP, proxy sidecar or connector, Workload Identity so there is no key file, least-privilege role.)
- A deploy is failing with CrashLoopBackOff. Steps? (`kubectl logs --previous`, `kubectl describe pod` for events and exit code, check env/secret mounts, check the liveness probe is not killing a slow-starting app, roll back with `kubectl rollout undo`.)
