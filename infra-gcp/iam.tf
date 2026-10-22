# One identity per workload, least privilege. Nothing here gets Editor or Owner.

# api-sa: what the running API may do. Connect to Cloud SQL, read one secret.
resource "google_service_account" "api" {
  account_id   = "api-sa"
  display_name = "two-tier API runtime identity"
  depends_on   = [google_project_service.apis]
}

resource "google_project_iam_member" "api_sql_client" {
  project = var.project
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.api.email}"
}

resource "google_secret_manager_secret_iam_member" "api_db_password" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

# Workload Identity: Kubernetes ServiceAccount two-tier/api acts as api-sa. No key file.
resource "google_service_account_iam_member" "api_workload_identity" {
  count              = var.create_gke ? 1 : 0
  service_account_id = google_service_account.api.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project}.svc.id.goog[two-tier/api]"
}

# nodes: the GKE node pool identity. Logs, metrics, and pulling images; nothing else.
resource "google_service_account" "nodes" {
  account_id   = "nodes"
  display_name = "GKE node pool identity"
}

resource "google_project_iam_member" "nodes" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ])
  project = var.project
  role    = each.value
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

# ci-sa: what the GitHub Actions pipeline may do. Push images; nothing in the cluster.
# Bound to the repo through Workload Identity Federation (Lab 5.1), no key file.
resource "google_service_account" "ci" {
  account_id   = "ci-sa"
  display_name = "CI pipeline identity"
}

resource "google_artifact_registry_repository_iam_member" "ci_push" {
  location   = var.region
  repository = google_artifact_registry_repository.apps.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.ci.email}"
}
