resource "google_artifact_registry_repository" "apps" {
  #checkov:skip=CKV_GCP_84: Google-managed encryption is acceptable here; CMEK adds a KMS key and rotation to run for a lab registry
  location      = var.region
  repository_id = "apps"
  format        = "DOCKER"
  labels        = local.labels
  depends_on    = [google_project_service.apis]

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions { keep_count = 20 }
  }
}
