"""Tier 1: a small Flask API.

Step 1 runs with no database (notes live in memory).
Step 3 sets DB_HOST and the same code switches to PostgreSQL.
"""
import os
import socket
from pathlib import Path

from flask import Flask, jsonify, request

app = Flask(__name__)

DB_HOST = os.environ.get("DB_HOST")  # unset = in-memory mode


def db_password():
    """Read the password from a file (Compose/Kubernetes secret) or an env var."""
    path = os.environ.get("DB_PASSWORD_FILE")
    if path:
        return Path(path).read_text().strip()
    return os.environ.get("DB_PASSWORD", "")


# ---- storage: in-memory or PostgreSQL ---------------------------------------
if DB_HOST:
    import psycopg

    def connect():
        return psycopg.connect(
            host=DB_HOST,
            port=int(os.environ.get("DB_PORT", "5432")),
            user=os.environ.get("DB_USER", "app"),
            password=db_password(),
            dbname=os.environ.get("DB_NAME", "app"),
            connect_timeout=3,
        )

    class Store:
        mode = "postgres"

        def init(self):
            with connect() as conn:
                conn.execute(
                    "CREATE TABLE IF NOT EXISTS notes ("
                    "id SERIAL PRIMARY KEY, text TEXT NOT NULL, "
                    "created_at TIMESTAMPTZ DEFAULT now())"
                )

        def list(self):
            with connect() as conn:
                rows = conn.execute("SELECT id, text, created_at FROM notes ORDER BY id").fetchall()
            return [{"id": r[0], "text": r[1], "created_at": r[2].isoformat()} for r in rows]

        def add(self, text):
            with connect() as conn:
                r = conn.execute(
                    "INSERT INTO notes (text) VALUES (%s) RETURNING id, text, created_at", (text,)
                ).fetchone()
            return {"id": r[0], "text": r[1], "created_at": r[2].isoformat()}

        def ping(self):
            with connect() as conn:
                conn.execute("SELECT 1")

else:
    from datetime import datetime, timezone

    class Store:
        mode = "memory"
        notes = []

        def init(self):
            pass

        def list(self):
            return self.notes

        def add(self, text):
            note = {"id": len(self.notes) + 1, "text": text,
                    "created_at": datetime.now(timezone.utc).isoformat()}
            self.notes.append(note)
            return note

        def ping(self):
            pass


store = Store()
store.init()


# ---- routes ------------------------------------------------------------------
@app.get("/")
def index():
    return jsonify(
        service="two-tier-api",
        version=os.environ.get("APP_VERSION", "dev"),
        storage=store.mode,
        hostname=socket.gethostname(),  # shows which replica answered
    )


@app.get("/healthz/live")
def live():
    """Liveness: is the process alive at all? Never touches the database."""
    return "ok"


@app.get("/healthz/ready")
def ready():
    """Readiness: can this replica serve traffic? Checks the database."""
    try:
        store.ping()
        return "ready"
    except Exception as exc:  # noqa: BLE001
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


if __name__ == "__main__":
    # Local run without Docker: python app.py
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
