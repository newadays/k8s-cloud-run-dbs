#!/usr/bin/env bash
# Build both images and load them into the kind cluster named "lab".
set -euo pipefail
docker build -t hello-py:1.0.0 apps/hello
docker build -t auth-py:1.0.0 apps/auth
kind load docker-image hello-py:1.0.0 auth-py:1.0.0 --name lab
