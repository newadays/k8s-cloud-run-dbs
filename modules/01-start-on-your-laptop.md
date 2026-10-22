# Module 0: Start on your laptop, one container at a time

Before any cloud account, run the whole two-tier app on your own machine. Every later module reuses this exact code and image, so by the time you reach GKE the only new thing is the platform. The starter repo (`two-tier-app-starter.zip`) has the code; this module is the ladder you climb with it. Budget about 70 minutes.

**The app, in one screen.** A Python Flask API, one file, with five routes: `GET /` (which replica answered, which storage is in use), `GET /healthz/live`, `GET /healthz/ready`, `GET /notes`, `POST /notes`. With no `DB_HOST` it keeps notes in memory; set `DB_HOST` and the same code uses PostgreSQL. That switch, driven only by environment variables, is the thing to internalize: one image, many environments.

```python
# app.py (abridged; the full file is in the starter repo)
import os, socket
from flask import Flask, jsonify, request

app = Flask(__name__)
DB_HOST = os.environ.get("DB_HOST")          # unset = in-memory mode
store = PostgresStore() if DB_HOST else MemoryStore()

@app.get("/")
def index():
    return jsonify(service="two-tier-api", storage=store.mode, hostname=socket.gethostname())

@app.get("/healthz/live")                     # process alive? never touches the DB
def live():
    return "ok"

@app.get("/healthz/ready")                    # can this replica serve? checks the DB
def ready():
    try:
        store.ping()
        return "ready"
    except Exception as exc:
        return f"database unreachable: {exc}", 503

@app.get("/notes")
def list_notes():
    return jsonify(store.list())

@app.post("/notes")
def add_note():
    text = (request.get_json(silent=True) or {}).get("text", "")
    if not text:
        return jsonify(error="text is required"), 400
    return jsonify(store.add(text)), 201
```

It runs under gunicorn in the container (`gunicorn app:app`), which handles SIGTERM gracefully so Kubernetes can drain a pod before stopping it. `python app.py` runs it without Docker when you just want to poke at the code.

**Step 1 (15 min): one container, one web service**

The first Dockerfile is deliberately plain; Module 2 hardens it.

```dockerfile
# Dockerfile.step1
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
ENV PORT=8080
EXPOSE 8080
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
```

```bash
docker build -f Dockerfile.step1 -t two-tier-api:0.1.0 .
docker run --rm -p 8080:8080 two-tier-api:0.1.0
# second terminal
curl localhost:8080/
curl -X POST localhost:8080/notes -H 'content-type: application/json' -d '{"text":"first note"}'
curl localhost:8080/notes
```

Stop the container (Ctrl-C), start it again, and `GET /notes` is empty. A container's memory dies with it. Say that sentence out loud; it is the reason a second tier exists and the reason the app tier must be stateless.

**Step 2 (10 min): look inside the container**

```bash
docker run -d --name api -p 8080:8080 two-tier-api:0.1.0
docker ps                       # running containers
docker logs api                 # gunicorn writes access and error logs to stdout; nothing to a file
docker exec -it api sh          # a shell inside the container
docker inspect api | head -40   # image digest, env, network, mounts
docker stats api --no-stream    # cpu and memory in use
docker stop api && docker rm api
```

Each command maps to something you will do on Kubernetes later: `docker logs` becomes `kubectl logs`, `docker exec` becomes `kubectl exec`, `docker inspect` becomes `kubectl describe`.

**Step 3 (15 min): add the database with Compose, two tiers on one laptop**

```yaml
# compose.yaml
services:
  api:
    build: .
    ports: ["8080:8080"]
    environment:
      DB_HOST: db                       # the service name is the DNS name
      DB_USER: app
      DB_NAME: app
      DB_PASSWORD_FILE: /run/secrets/db_password
    secrets: [db_password]
    depends_on:
      db: { condition: service_healthy }
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: app
      POSTGRES_DB: app
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    volumes: [pgdata:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app"]
      interval: 5s
secrets:
  db_password: { file: ./db_password.txt }
volumes:
  pgdata:
```

```bash
cp db_password.txt.example db_password.txt   # never commit the real file
docker compose up --build
```

`POST /notes`, then `docker compose restart api`, then `GET /notes`: the note is still there, because it lives in the `db` container's volume, not in the API. `GET /` now says `"storage": "postgres"` and no code changed. Three things to notice: the API found the database by the service name `db` (Compose runs a DNS server, as Kubernetes will), the password arrived as a file rather than a baked-in value, and `depends_on` with a health check kept the API from starting before Postgres was ready.

**Step 4 (20 min): the same image on local Kubernetes**

```bash
kind create cluster --name lab
kind load docker-image two-tier-api:0.1.0 --name lab   # no registry yet
kubectl apply -f k8s-local/                            # Deployment (2 replicas) + Service
kubectl get pods -w                                    # wait for Running and 1/1 Ready
kubectl port-forward svc/api 8080:80
```

`curl localhost:8080/` several times and watch `hostname` change: the Service is spreading requests over two replicas. `kubectl delete pod <one>` and watch the Deployment replace it within seconds. Then `kubectl logs`, `kubectl exec`, `kubectl describe pod` on one of them and compare to Step 2. The database is not in this cluster, so the app is back in memory mode; that is on purpose. Module 4 attaches a managed database rather than running Postgres inside the cluster, and Lab 4.2 has you try the in-cluster version so you can explain why.

**Step 5 (10 min): the production image**

```bash
docker build -t two-tier-api:0.2.0 .     # the multi-stage, non-root Dockerfile
docker images two-tier-api               # compare sizes
docker run -d --name api2 -p 8080:8080 two-tier-api:0.2.0
docker exec -it api2 id                  # uid=10001(appuser): not root, by design
docker exec -it api2 pip --version       # fails: no pip in the runtime image
```

Both results are features, and Module 2 explains every line of the Dockerfile that produced them.

**Cleanup for this module**

```bash
docker compose down -v
kind delete cluster --name lab
docker rmi two-tier-api:0.1.0 two-tier-api:0.2.0
```

**Interview questions this module answers**

- What is a container? (A process with its own view of the filesystem, network, and process table, enforced by Linux namespaces and cgroups. Not a VM; it shares the host kernel.)
- Where did the data go when the container restarted? (Container filesystems are ephemeral. Persistent data needs a volume or an external service; the app tier should hold none.)
- How did the API find the database? (By service name over the Compose network's DNS; the same pattern as a Kubernetes Service.)
- What does readiness mean versus liveness, in code? (Liveness: the process responds at all. Readiness: its dependencies answer. Point to the two routes.)
- What is the difference between `docker compose` and Kubernetes? (Compose runs containers on one host with no scheduling, self-healing, or rolling updates. Kubernetes schedules across nodes and reconciles desired state. You saw both in an hour.)
