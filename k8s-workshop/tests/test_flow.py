"""End-to-end check of the login -> secure flow without Docker: python -m pytest"""
import importlib.util, os, sys, pathlib

os.environ["JWT_SECRET"] = "test-secret"
ROOT = pathlib.Path(__file__).resolve().parent.parent

def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "apps" / name / "app.py")
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
    mod.app.testing = True
    return mod.app.test_client()

def test_login_then_secure():
    hello, auth = load("hello"), load("auth")
    assert hello.get("/").get_json()["message"] == "Hello"
    assert hello.get("/secure").status_code == 401
    assert auth.get("/login").status_code == 401
    token = auth.get("/login", auth=("user", "password")).get_json()["token"]
    r = hello.get("/secure", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200 and "Hello user" in r.get_json()["message"]
    assert hello.get("/healthz").data == b"ok" and auth.get("/version").get_json()["version"] == "1.0.0"
