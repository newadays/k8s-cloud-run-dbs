#!/usr/bin/env bash
# Module 2 lab: grant the compute service account what Cloud Run needs, then deploy.
#   ./cloudrun-lab.sh grant    # one-time IAM grants
#   ./cloudrun-lab.sh deploy   # build from source and deploy to Cloud Run
#   ./cloudrun-lab.sh test     # curl the service
set -euo pipefail

PROJECT=winged-yeti-511917-t6
REGION=us-central1
SA=622192507024-compute@developer.gserviceaccount.com
INSTANCE=$PROJECT:$REGION:two-tier-db

case "${1:-}" in
  grant)
    gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$SA" --role=roles/cloudbuild.builds.builder --condition=None
    gcloud projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$SA" --role=roles/cloudsql.client --condition=None
    gcloud secrets add-iam-policy-binding db-password --member="serviceAccount:$SA" --role=roles/secretmanager.secretAccessor
    ;;
  deploy)
    cd "$(dirname "$0")"
    gcloud run deploy api --source . --region="$REGION" --allow-unauthenticated \
      --add-cloudsql-instances "$INSTANCE" \
      --set-secrets DB_PASSWORD=db-password:latest \
      --set-env-vars "DB_HOST=/cloudsql/$INSTANCE,DB_USER=app,DB_NAME=app" \
      --network=two-tier-vpc --subnet=app-subnet --vpc-egress=private-ranges-only
    ;;
  test)
    URL=$(gcloud run services describe api --region="$REGION" --format='value(status.url)')
    echo "URL: $URL"
    curl -s "$URL/"; echo
    curl -s -X POST -H 'Content-Type: application/json' -d '{"text":"hello from cloud run"}' "$URL/notes"; echo
    curl -s "$URL/notes"; echo
    ;;
  *)
    echo "usage: $0 grant|deploy|test"; exit 1 ;;
esac
