"""hello: the application service. Python port of kelseyhightower/app 'hello'.

Routes: / (public), /secure (needs a JWT from the auth service), /healthz, /readiness, /version
"""
import os
import socket

import jwt
from flask import Flask, jsonify, request

app = Flask(__name__)
VERSION = os.environ.get("APP_VERSION", "1.0.0")
JWT_SECRET = os.environ.get("JWT_SECRET", "change-me")  # injected from a Kubernetes Secret


@app.get("/")
def hello():
    return jsonify(message="Hello", served_by=socket.gethostname())


@app.get("/secure")
def secure():
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return jsonify(error="missing bearer token"), 401
    try:
        claims = jwt.decode(auth.split(" ", 1)[1], JWT_SECRET, algorithms=["HS256"])
    except jwt.PyJWTError as exc:
        return jsonify(error=f"invalid token: {exc}"), 401
    return jsonify(message=f"Hello {claims['sub']}, this is the secure endpoint", served_by=socket.gethostname())


@app.get("/healthz")
def healthz():
    return "ok"


@app.get("/readiness")
def readiness():
    return "ok"


@app.get("/version")
def version():
    return jsonify(version=VERSION)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "80")))
