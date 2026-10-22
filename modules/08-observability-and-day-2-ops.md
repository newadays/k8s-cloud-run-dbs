# Module 7: Observability, troubleshooting, and day-2 operations

Interviewers for this role usually spend the last fifteen minutes on "it is 2am and the API is returning 503s." The answer is a fixed order of checks, not a guess.

**The debugging ladder, outside in**

1. Is it the edge? Load balancer health check status, certificate expiry, DNS. `kubectl describe ingress api -n two-tier` shows backend health.
2. Is it the Service? `kubectl get endpoints api -n two-tier`: no endpoints means no pod passes readiness or the selector does not match the labels.
3. Is it the pods? `kubectl get pods -n two-tier`: CrashLoopBackOff (app exits: read `kubectl logs --previous`), ImagePullBackOff (registry auth or wrong digest), Pending (resources, taints, PVC), OOMKilled (raise the memory limit or fix the leak), Running but not Ready (readiness probe failing: check the endpoint it hits).
4. Is it the node? `kubectl get nodes`, `kubectl describe node`: DiskPressure, MemoryPressure, NotReady. `kubectl top nodes` and `kubectl top pods`.
5. Is it the dependency? The Cloud SQL proxy sidecar logs, connection count on the database, IAM binding still present.
6. What changed? `kubectl rollout history`, Argo CD sync history, the config repo's last commits. Roll back first, root-cause second.

**Three pillars, and what to say about each**

| Pillar | Lab tooling (GKE) | Open-source equivalent | One thing to say |
| --- | --- | --- | --- |
| Metrics | Cloud Monitoring, Managed Service for Prometheus | Prometheus + Grafana, kube-state-metrics | Define SLOs (availability, p99 latency) and alert on error budget burn, not on CPU |
| Logs | Cloud Logging (auto-collected from stdout) | Loki, Fluent Bit, Elastic | Structured JSON logs to stdout; never write to files inside the container |
| Traces | Cloud Trace via OpenTelemetry | Jaeger, Tempo | OpenTelemetry SDK in the app, propagate trace IDs across the tiers |

**Lab 7.1 (30 min): see it break on purpose**

- Set the API's memory limit to 32Mi and watch OOMKilled; raise it back.
- Point the readiness probe at a wrong path and watch the Service lose its endpoints while pods stay Running.
- `kubectl cordon` a node and `kubectl drain --ignore-daemonsets` it; confirm the PDB keeps two replicas serving throughout.
- Delete the Workload Identity binding and watch the proxy sidecar log 403s; restore it.

**Day-2 topics to have one sentence ready for**

- Cluster upgrades: release channel, surge upgrades, PDBs, maintenance windows, test on staging first.
- Cost: requests sized from VPA recommendations, Cluster Autoscaler with a spot/preemptible node pool for stateless work, committed-use discounts, delete idle namespaces.
- Backups and DR: Cloud SQL automated backups and point-in-time recovery; cluster state is in Git (GitOps) so a cluster is rebuildable; Velero for PVCs if any.
- Multi-environment: one cluster per environment or namespaces plus policy; most teams: shared non-prod cluster, dedicated prod.
- Graceful shutdown: handle SIGTERM, `terminationGracePeriodSeconds`, a `preStop` sleep so the load balancer stops sending traffic before the process exits.
