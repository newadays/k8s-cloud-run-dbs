"""auth: issues JWTs. Python port of kelseyhightower/app 'auth'.

Routes: /login (HTTP basic auth -> JWT), /healthz, /readiness, /version
"""
import os
from datetime import datetime, timedelta, timezone

import jwt
from flask import Flask, jsonify, request

app = Flask(__name__)
VERSION = os.environ.get("APP_VERSION", "1.0.0")
JWT_SECRET = os.environ.get("JWT_SECRET", "change-me")  # same Secret the hello service reads
USERS = {"user": "password"}  # demo only


@app.get("/login")
def login():
    creds = request.authorization
    if not creds or USERS.get(creds.username) != creds.password:
        return jsonify(error="bad credentials"), 401, {"WWW-Authenticate": 'Basic realm="auth"'}
    token = jwt.encode(
        {"sub": creds.username, "iat": datetime.now(timezone.utc),
         "exp": datetime.now(timezone.utc) + timedelta(hours=1)},
        JWT_SECRET, algorithm="HS256",
    )
    return jsonify(token=token)


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
