# Module 3b: The Google "Getting started with Kubernetes" demo, in Python

The Kubernetes Essentials video [Getting started with Kubernetes](https://www.youtube.com/watch?v=LYcHaDDcCYo) (Carter Morgan and Kaslin Fields, Google Cloud Tech) deploys a three-part app declaratively: a `hello` service, an `auth` service that issues JWTs, and an nginx `frontend` that terminates TLS and routes to both. The original is Go; `k8s-workshop/` in the course zip is the same app in Python, with the same file layout so the video's commands run unchanged. Budget 60 minutes.

```
k8s-workshop/
  apps/hello/app.py     Flask: /  /secure (needs a JWT)  /healthz  /readiness  /version
  apps/auth/app.py      Flask: /login (basic auth user/password, returns a JWT)
  deployments/          hello.yaml  auth.yaml  frontend.yaml
  services/             hello.yaml  auth.yaml  frontend.yaml
  nginx/frontend.conf   becomes ConfigMap nginx-frontend
  tls/generate.sh       makes cert.pem and key.pem, which become Secret tls-certs
```

**The two pieces the video says keep track of pods.** The control plane exposes one API (kube-apiserver); `kubectl apply` is an HTTP request to it, and the desired state lands in etcd. On every node, the kubelet starts the containers the API server assigned to that node and reports pod status back, and kube-proxy programs the node's routing so a Service IP reaches the right pods. Nothing else on the node knows or cares about Deployments; those are reconciled by controllers on the control plane.

**Step 1: cluster, images, shared secret**

```bash
kind create cluster --name lab
./build.sh                 # docker build hello-py:1.0.0 and auth-py:1.0.0, kind load both
kubectl create secret generic jwt-secret --from-literal=secret="$(openssl rand -hex 32)"
```

Both Deployments read `JWT_SECRET` from this Secret, so a token signed by auth is accepted by hello. The original demo hard-coded the signing key in the Go source; a Secret is what you would do in a real cluster.

**Step 2: deploy declaratively.** `kubectl apply -f` takes several files in one call and makes the cluster match them; run it again and it reports `unchanged`. That idempotence is why CI/CD pipelines are built on `apply`, not on `create`.

```bash
kubectl apply -f deployments/hello.yaml -f services/hello.yaml
```

**Step 3: ConfigMap for nginx, Secret for TLS, then the frontend.** The frontend pod mounts a ConfigMap at `/etc/nginx/conf.d` and a Secret at `/etc/tls`, so both must exist before the pod can start.

```bash
kubectl create configmap nginx-frontend --from-file nginx/frontend.conf
./tls/generate.sh
kubectl create secret generic tls-certs --from-file tls/
kubectl apply -f deployments/frontend.yaml -f services/frontend.yaml
kubectl describe configmap nginx-frontend
kubectl get secret tls-certs -o yaml       # base64, not encryption; see Module 6
kubectl describe deploy frontend           # the volumes and volumeMounts sections
```

ConfigMap versus Secret: same mechanism (key/value, mountable as files or env vars), different intent and different RBAC. A Secret's values are base64-encoded in etcd and readable by anyone with `get secrets` in the namespace; Module 6 covers encrypting them at rest and keeping the source of truth outside the cluster.

**Step 4: auth**

```bash
kubectl apply -f services/auth.yaml -f deployments/auth.yaml
```

**Step 5: test.** The video's `kubectl get svc frontend` shows the LoadBalancer's EXTERNAL-IP on GKE. On kind it stays `<pending>` because there is no cloud load balancer; use a port-forward instead.

```bash
kubectl get svc frontend
kubectl port-forward svc/frontend 8443:443 &      # kind only
HOST=https://localhost:8443                       # GKE: https://<EXTERNAL-IP>
curl -k $HOST/                                    # {"message":"Hello","served_by":"hello-..."}
curl -k $HOST/secure                              # 401
curl -k -u user:password $HOST/login              # {"token":"eyJ..."}
TOKEN=$(curl -sk -u user:password $HOST/login | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
curl -k -H "Authorization: Bearer $TOKEN" $HOST/secure
```

Run `curl -k $HOST/` several times and watch `served_by` rotate across the three hello pods: kube-proxy spreading one Service IP over three endpoints.

**Step 6: namespaces.** A namespace is a scope for names and for RBAC; `kubectl get deploy -n production` is empty until you deploy there, and the current context's namespace is just a default for the `-n` flag.

```bash
kubectl get namespaces
kubectl describe namespace default
kubectl create namespace production
kubectl get deploy -n production
kubectl config set-context --current --namespace=production
kubectl get deploy                                # now scoped to production
kubectl config set-context --current --namespace=default
```

The nginx upstreams are written as `hello.default.svc.cluster.local`; that is the full Service DNS name, `<service>.<namespace>.svc.cluster.local`. Moving the app to another namespace means changing that string and recreating the ConfigMap, which is a good small exercise.

**Cleanup**

```bash
kubectl delete -f deployments/ -f services/
kubectl delete configmap nginx-frontend
kubectl delete secret tls-certs jwt-secret
kubectl delete namespace production
```

**Interview questions this module answers**

- `kubectl create` versus `kubectl apply`? (create fails if the object exists; apply computes a diff against the last applied configuration and converges. Pipelines use apply.)
- How does a pod get configuration? (ConfigMap or Secret, as env vars or mounted files; mounted files update in place when the ConfigMap changes, env vars do not.)
- What is `hello.default.svc.cluster.local`? (CoreDNS name for a Service: name, namespace, `svc`, cluster domain. Inside the same namespace `hello` alone resolves.)
- Why does a LoadBalancer Service stay pending on kind? (No cloud controller to provision one. On GKE the cloud controller manager creates a Google load balancer and writes its IP into the Service status.)
- What are namespaces for, and what are they not? (Scoping names, RBAC, quotas, and NetworkPolicy. Not a security boundary on their own; nodes and the cluster are shared.)
