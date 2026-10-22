# Module 3: Kubernetes fundamentals and deploying a cluster

Kubernetes is a control loop: you declare desired state in the API server, controllers compare it to observed state, and they act until the two match. Every interview question about Kubernetes is some version of "which controller, which object, which loop."

**The control plane and the node, in one table**

| Component | Lives on | Job | Classic question |
| --- | --- | --- | --- |
| kube-apiserver | Control plane | Only thing that reads/writes etcd; all clients talk to it | "What happens when you run kubectl apply?" |
| etcd | Control plane | Key-value store of all cluster state | "What if etcd is lost?" (cluster state is lost; back it up) |
| kube-scheduler | Control plane | Picks a node for each unscheduled pod | "Why is my pod Pending?" |
| controller-manager | Control plane | Runs Deployment, ReplicaSet, Node, Job controllers | "Who creates the pods for a Deployment?" |
| kubelet | Every node | Starts containers the API server assigns to this node; reports health | "Why is my node NotReady?" |
| kube-proxy / CNI | Every node | Service routing (iptables/eBPF) and pod networking | "How does a Service find pods?" |

On GKE, EKS, and AKS you never see the control plane; the provider runs it. You own the node pools (or let Autopilot/Fargate own those too).

**Lab 3.1 (20 min): a free local cluster to learn the objects**

```bash
kind create cluster --name lab
kubectl get nodes
kubectl create deployment hello --image=nginx --replicas=3
kubectl get pods -o wide            # three pods, maybe on one node
kubectl scale deployment hello --replicas=5
kubectl delete pod <one pod name>  # watch the ReplicaSet replace it
kubectl rollout history deployment hello
kubectl set image deployment/hello nginx=nginx:1.27
kubectl rollout status deployment hello
kubectl rollout undo deployment hello
```

Read the output of each command and say out loud which controller did the work. That narration is exactly what the interviewer wants to hear.

**Lab 3.2 (40 min): a production-shaped GKE cluster with Terraform**

```hcl
resource "google_container_cluster" "two_tier" {
  name                     = "two-tier"
  location                 = "us-central1"          # regional: control plane in 3 zones
  network                  = google_compute_network.vpc.id
  subnetwork               = google_compute_subnetwork.app.id
  remove_default_node_pool = true
  initial_node_count       = 1
  networking_mode          = "VPC_NATIVE"
  ip_allocation_policy {}
  private_cluster_config {
    enable_private_nodes    = true              # nodes get no public IP
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
  master_authorized_networks_config {
    cidr_blocks { cidr_block = "YOUR_IP/32" display_name = "me" }
  }
  workload_identity_config { workload_pool = "PROJECT.svc.id.goog" }
  release_channel { channel = "REGULAR" }
  binary_authorization { evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE" }
}

resource "google_container_node_pool" "general" {
  name       = "general"
  cluster    = google_container_cluster.two_tier.id
  node_count = 1                                   # per zone, so 3 total
  autoscaling { min_node_count = 1  max_node_count = 3 }
  management  { auto_repair = true  auto_upgrade = true }
  node_config {
    machine_type    = "e2-medium"
    service_account = google_service_account.nodes.email   # not the default SA
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    shielded_instance_config { enable_secure_boot = true }
    workload_metadata_config { mode = "GKE_METADATA" }
  }
}
```

`terraform init && terraform apply`, then `gcloud container clusters get-credentials two-tier --region us-central1` and `kubectl get nodes`. Each flagged line is an interview answer: regional for HA, private nodes so there is no public attack surface, authorized networks on the API server, a dedicated node service account, Workload Identity for pod-to-cloud auth, release channel for managed upgrades, Binary Authorization for signed images.

**Equivalents to be able to name**

| GKE term | EKS | AKS |
| --- | --- | --- |
| Autopilot (serverless nodes) | Fargate profiles / EKS Auto Mode | Virtual nodes / Automatic |
| Node pool | Managed node group | Node pool |
| Workload Identity | IRSA / EKS Pod Identity | Workload Identity |
| Private cluster + authorized networks | Private endpoint + security group | Private cluster + API authorized ranges |
| `gcloud container clusters get-credentials` | `aws eks update-kubeconfig` | `az aks get-credentials` |
| GKE Dataplane V2 (Cilium, eBPF) | VPC CNI (+ Cilium optional) | Azure CNI (+ Cilium) |

**Interview questions this module answers**

- Explain the Kubernetes architecture. (Use the first table; finish with "it is all control loops reconciling desired and observed state.")
- Standard vs Autopilot (or managed node groups vs Fargate)? (Autopilot: you pay per pod, no node management, stricter defaults. Standard: full node control, needed for GPUs, DaemonSets, privileged pods, custom kernels.)
- How would you make the cluster highly available? (Regional control plane, node pools across zones, PodDisruptionBudgets, topology spread constraints, regional database.)
- How do you upgrade a cluster safely? (Release channel, surge upgrades one node at a time, PDBs so drains do not kill all replicas, upgrade a staging cluster first, read the deprecation list for the target version.)
- My pod is Pending. What do you check? (`kubectl describe pod`: insufficient CPU/memory, node selector/affinity/taint mismatch, PVC not bound, image pull errors show as a different state.)
