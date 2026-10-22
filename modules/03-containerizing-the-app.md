# Module 2: Containerizing the two-tier app

A good production Dockerfile is small, runs as non-root, and builds the same way every time. Most of what interviewers probe here is whether you know why each line exists.

**Lab 2.1 (30 min): a production-grade Dockerfile for the API**

```dockerfile
# ---- build stage: install dependencies with pip and any compilers ----
FROM python:3.12-slim AS build
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- runtime stage: only the interpreter, the installed packages, and app.py ----
FROM python:3.12-slim
WORKDIR /app
COPY --from=build /install /usr/local
COPY app.py .
RUN useradd --uid 10001 --no-create-home appuser
USER 10001
ENV PORT=8080 PYTHONUNBUFFERED=1
EXPOSE 8080
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
```

Why each choice matters:

| Line | What it buys you | Interview phrase |
| --- | --- | --- |
| Multi-stage build | Runtime image has no pip cache, no compilers, no dev packages | "Smaller attack surface and faster pulls" |
| Pinned `requirements.txt` | Reproducible dependency set | "Same bits in CI and production" |
| `python:3.12-slim` base | No build toolchain, far fewer CVEs than the full image | "Less for an attacker to use" |
| `useradd` + `USER 10001` | Container breakout does not land as root | "Defense in depth; Pod Security Standards require it" |
| `COPY requirements.txt` before `COPY app.py` | Dependency layer is cached until requirements change | "Layer caching: order from least to most volatile" |
| `PYTHONUNBUFFERED=1` | Logs reach stdout immediately | "Twelve-factor logging: stdout, not files" |
| gunicorn instead of `python app.py` | Production WSGI server; finishes in-flight requests on SIGTERM. Add --workers and --threads later when you size the pod | "Zero-downtime rollouts need graceful shutdown" |
| Pinned tags (`python:3.12-slim`, better: a digest) | Builds do not silently change under you | "Pin by digest in production" |

**Lab 2.2 (20 min): local two-tier with Docker Compose**

```yaml
services:
  api:
    build: .
    ports: ["8080:8080"]
    environment:
      DB_HOST: db
      DB_USER: app
      DB_PASSWORD_FILE: /run/secrets/db_password
    secrets: [db_password]
    depends_on:
      db: { condition: service_healthy }
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: app
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

Run `docker compose up --build`, confirm the API connects, then `docker compose down -v`. Compose is for local development; the interview point is that the same image you built here is what ships, unchanged, through every environment.

**Lab 2.3 (15 min): push to a registry and scan it**

1. `gcloud artifacts repositories create apps --repository-format=docker --location=us-central1`
2. `gcloud auth configure-docker us-central1-docker.pkg.dev`
3. `docker build -t us-central1-docker.pkg.dev/PROJECT/apps/api:0.1.0 .` then `docker push ...`
4. `trivy image us-central1-docker.pkg.dev/PROJECT/apps/api:0.1.0` and read the report. Rebuild on the full `python:3.12` image instead of `-slim` and compare the CVE count; that difference is your answer to "why slim."
5. Note the image digest (`sha256:...`); Module 6 will deploy by digest, not tag.

**Interview questions this module answers**

- What is the difference between an image and a container? (Image: immutable layered filesystem plus metadata. Container: a running process with namespaces and cgroups applied, using that image as its root filesystem.)
- How do you keep images small and secure? (Multi-stage, distroless or slim base, non-root user, no secrets in layers, scan in CI, pin by digest.)
- Why not `latest`? (Non-reproducible; two nodes can pull different images; rollbacks become guesswork.)
- Where does the database password live in the container? (Nowhere. Injected at runtime from a secret store, read from a file or env var, never in the image or the repo.)
