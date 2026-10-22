# two-tier-app

A small Python (Flask) API (tier 1) that stores notes in memory until you give it a PostgreSQL database (tier 2). The same code and image are used in every step of the course, from one container on your laptop to GKE.

Files: `app.py` (the whole service), `requirements.txt`, `Dockerfile.step1` (plain), `Dockerfile` (production), `compose.yaml`, `k8s-local/`, `tests/`.

Endpoints: `GET /` (who answered, which storage), `GET /healthz/live`, `GET /healthz/ready`, `GET /notes`, `POST /notes {"text": "..."}`.

## Step 0: run it with plain Python (5 min, optional)

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
python -m pytest            # 1 passed
python app.py               # http://localhost:8080
```

## Step 1: one container, one web service (15 min)

```bash
docker build -f Dockerfile.step1 -t two-tier-api:0.1.0 .
docker run --rm -p 8080:8080 two-tier-api:0.1.0
```

In a second terminal:

```bash
curl localhost:8080/
curl -X POST localhost:8080/notes -H 'content-type: application/json' -d '{"text":"first note"}'
curl localhost:8080/notes
```

Stop it with Ctrl-C. Run it again and `GET /notes` is empty: a container's memory dies with it. That is the whole reason tier 2 exists.

## Step 2: look inside (10 min)

```bash
docker run -d --name api -p 8080:8080 two-tier-api:0.1.0
docker ps                          # the running container
docker logs api                    # gunicorn access and error logs on stdout
docker exec -it api sh             # a shell inside
docker inspect api | head -40      # image, env, network, mounts
docker stats api --no-stream       # cpu and memory
docker stop api && docker rm api
```

## Step 3: add the database with Compose (15 min)

```bash
cp db_password.txt.example db_password.txt   # edit if you like; never commit it
docker compose up --build
```

Now `POST /notes`, then `docker compose restart api`, then `GET /notes`: the note survives because it lives in the `db` container's volume. `docker compose down` keeps the volume; `docker compose down -v` deletes it.

`GET /` now reports `"storage": "postgres"`. Nothing in the code changed; only `DB_HOST` did.

## Step 4: the same image on local Kubernetes (20 min)

```bash
kind create cluster --name lab
kind load docker-image two-tier-api:0.1.0 --name lab
kubectl apply -f k8s-local/
kubectl get pods -w                 # wait for 2/2 Running and Ready
kubectl port-forward svc/api 8080:80
```

`curl localhost:8080/` several times: the `hostname` changes as the Service spreads requests across the two replicas. `kubectl delete pod <one of them>` and watch the Deployment replace it.

## Step 5: the production image (10 min)

```bash
docker build -t two-tier-api:0.2.0 .          # multi-stage, non-root
docker run --rm -p 8080:8080 two-tier-api:0.2.0
docker exec -it <id> id                       # uid=10001(appuser), not root
```

Compare `docker images two-tier-api` sizes, then continue with Module 2 of the course for why each line of the production Dockerfile exists.

## Cleanup

```bash
docker compose down -v
kind delete cluster --name lab
docker rmi two-tier-api:0.1.0 two-tier-api:0.2.0
```
