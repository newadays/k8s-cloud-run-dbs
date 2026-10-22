#!/usr/bin/env bash
# Generates a self-signed TLS cert for the nginx frontend. Output: tls/cert.pem, tls/key.pem
set -euo pipefail
cd "$(dirname "$0")"
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -subj "/CN=frontend.local" -addext "subjectAltName=DNS:frontend.local,DNS:localhost,IP:127.0.0.1" \
  -keyout key.pem -out cert.pem
echo "wrote $(pwd)/cert.pem and key.pem"
