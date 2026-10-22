# k8s-workshop: "Getting started with Kubernetes", in Python

A Python port of the demo app from Google Cloud's *Kubernetes Essentials* video "Getting started with Kubernetes" (the Go `hello` / `auth` / nginx frontend app by Kelsey Hightower). Same layout, same `kubectl` commands, Python under the hood.

```
apps/hello/      Flask: /  /secure (needs JWT)  /healthz  /readiness  /version
apps/auth/       Flask: /login (basic auth user/password -> JWT)  /healthz  /readiness  /version
deployments/     hello.yaml  auth.yaml  frontend.yaml
services/        hello.yaml  auth.yaml  frontend.yaml
nginx/           frontend.conf   -> ConfigMap nginx-frontend
tls/             generate.sh     -> Secret tls-certs
```

Request path: client → **frontend** (nginx, TLS) → `/` to **hello**, `/login` to **auth**. hello and auth share one Kubernetes Secret (`jwt-secret`) so a token issued by auth is accepted by hello.

## 0. Concepts the demo assumes

| Piece | Lives on | What it does |
| --- | --- | --- |
| kube-apiserver | control plane | The API. Everything, including `kubectl`, talks to it; it writes desired state to etcd |
| kubelet | every node | Starts the containers the API server assigns to that node and reports pod status back |
| kube-proxy | every node | Programs the node's routing so a Service IP reaches the right pods |
| Deployment | API object | "I want N replicas of this pod"; a controller makes it true |
| Service | API object | A stable name and IP in front of a changing set of pods |
| ConfigMap / Secret | API objects | Non-sensitive and sensitive configuration, mounted as files or env vars |

## 1. Cluster and images

```bash
kind create cluster --name lab
./build.sh                         # builds hello-py:1.0.0 and auth-py:1.0.0, loads them into kind
```

On GKE instead: tag and push to Artifact Registry, then change `image:` in the two deployments.

## 2. Secret shared by hello and auth

```bash
kubectl create secret generic jwt-secret --from-literal=secret="$(openssl rand -hex 32)"
```

## 3. Deploy hello and the frontend declaratively

```bash
kubectl apply -f deployments/hello.yaml -f services/hello.yaml
```

The frontend needs its config and certificates to exist before its pod can start:

```bash
kubectl create configmap nginx-frontend --from-file nginx/frontend.conf
./tls/generate.sh
kubectl create secret generic tls-certs --from-file tls/
kubectl apply -f deployments/frontend.yaml -f services/frontend.yaml
```

Look at what you made:

```bash
kubectl get pods,deploy,svc
kubectl describe configmap nginx-frontend
kubectl get secret tls-certs -o yaml        # values are base64, not encrypted
kubectl describe deploy frontend            # see the volumes section
```

## 4. Deploy auth

```bash
kubectl apply -f services/auth.yaml -f deployments/auth.yaml
```

## 5. Test

```bash
kubectl get svc frontend        # on GKE wait for EXTERNAL-IP; on kind it stays <pending>
# kind: open a tunnel instead
kubectl port-forward svc/frontend 8443:443 &
export HOST=https://localhost:8443          # GKE: https://<EXTERNAL-IP>

curl -k $HOST/                              # {"message":"Hello","served_by":"hello-..."}
curl -k $HOST/secure                        # 401, no token
curl -k -u user:password $HOST/login        # {"token":"eyJ..."}
TOKEN=$(curl -sk -u user:password $HOST/login | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
curl -k -H "Authorization: Bearer $TOKEN" $HOST/secure
```

Run `curl -k $HOST/` a few times: `served_by` rotates across the three hello pods. That is the Service plus kube-proxy doing their job.

## 6. Namespaces

```bash
kubectl get namespaces
kubectl describe namespace default
kubectl create namespace production
kubectl get deploy -n production                       # empty: namespaces isolate objects
kubectl apply -n production -f deployments/hello.yaml -f services/hello.yaml   # would also need jwt-secret there
kubectl config set-context --current --namespace=production
kubectl get deploy                                     # now defaults to production
kubectl config set-context --current --namespace=default
```

Note: `nginx/frontend.conf` names the upstreams as `hello.default.svc.cluster.local`; if you move everything to `production`, change `default` there and recreate the ConfigMap.

## 7. Rolling update

```bash
# change a message in apps/hello/app.py, then
docker build -t hello-py:2.0.0 apps/hello && kind load docker-image hello-py:2.0.0 --name lab
kubectl set image deployment/hello hello=hello-py:2.0.0
kubectl rollout status deployment/hello
kubectl rollout undo deployment/hello
```

## Tests (no Docker needed)

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install flask PyJWT pytest && python -m pytest
```

## Cleanup

```bash
kubectl delete -f deployments/ -f services/
kubectl delete configmap nginx-frontend
kubectl delete secret tls-certs jwt-secret
kubectl delete namespace production
kind delete cluster --name lab
```
