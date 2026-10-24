#!/usr/bin/env bash
# Lab 4.1: render the raw manifests with PROJECT and DIGEST, then kubectl apply.
#   ./apply.sh                    # apply
#   ./apply.sh --dry-run=client   # any extra args go to kubectl apply
# PROJECT comes from the repo-root .env (or the environment); DIGEST from the environment:
#   export DIGEST=$(gcloud artifacts docker images describe us-central1-docker.pkg.dev/$PROJECT/apps/api:0.1.0 --format='value(image_summary.digest)')
set -euo pipefail
cd "$(dirname "$0")"
[ -f ../../.env ] && set -a && . ../../.env && set +a
: "${PROJECT:?set PROJECT in .env or the environment}"
: "${DIGEST:?export DIGEST=sha256:... (the image you pushed)}"
for f in *.yaml; do cat "$f"; echo "---"; done | sed -e "s|\${PROJECT}|$PROJECT|g" -e "s|\${DIGEST}|$DIGEST|g" | kubectl apply "$@" -f -
