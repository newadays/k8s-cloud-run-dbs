# charts/api

Helm chart for the two-tier app's API tier. One chart, three value files: `values.yaml` (defaults), `values-staging.yaml`, `values-prod.yaml`.

```bash
helm lint charts/api -f charts/api/values-staging.yaml
helm template api charts/api -f charts/api/values-staging.yaml | less          # see exactly what will be applied

kubectl create namespace two-tier-staging
kubectl -n two-tier-staging create secret generic db-credentials --from-literal=password="$(gcloud secrets versions access latest --secret db-password)"
helm upgrade --install api charts/api -n two-tier-staging -f charts/api/values-staging.yaml \
  --set gcp.project=$PROJECT --set image.digest=sha256:DIGEST --atomic --timeout 5m   # PROJECT from the repo-root .env
helm -n two-tier-staging test api
helm -n two-tier-staging history api
helm -n two-tier-staging rollback api 1
```

What the chart renders: ServiceAccount (Workload Identity annotation), ConfigMap (env), Deployment (API + Cloud SQL proxy sidecar, probes, security context, config checksum annotation), Service, Ingress + ManagedCertificate, HPA, PodDisruptionBudget, NetworkPolicy (default deny + allow), and a `helm test` pod. The DB password is read from an existing Secret named in `secret.name`; the chart never contains it. The GCP project is never in the chart either: `gcp.project` is passed at install time and the image path, Workload Identity annotation, and Cloud SQL connection name are derived from it in `_helpers.tpl`.

Guardrails baked in: `image.digest` is required for releases into the `two-tier-prod` namespace (`_helpers.tpl`), and `cloudSqlProxy.instanceConnectionName` is required when the sidecar is on.
