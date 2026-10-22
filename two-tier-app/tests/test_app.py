"""Smoke test in memory mode: python -m pytest"""
import os

os.environ.pop("DB_HOST", None)  # force in-memory mode before importing the app
import app as application  # noqa: E402


def client():
    application.app.testing = True
    return application.app.test_client()


def test_health_and_notes():
    c = client()
    assert c.get("/healthz/live").data == b"ok"
    assert c.get("/healthz/ready").data == b"ready"
    assert c.get("/").get_json()["storage"] == "memory"
    r = c.post("/notes", json={"text": "hello"})
    assert r.status_code == 201
    notes = c.get("/notes").get_json()
    assert len(notes) == 1 and notes[0]["text"] == "hello"
    assert c.post("/notes", json={}).status_code == 400
