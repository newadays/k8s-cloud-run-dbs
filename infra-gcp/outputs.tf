output "vpc" { value = google_compute_network.vpc.name }

output "db_connection_name" {
  description = "For the Cloud SQL proxy sidecar: PROJECT:REGION:INSTANCE"
  value       = google_sql_database_instance.db.connection_name
}

output "db_private_ip" { value = google_sql_database_instance.db.private_ip_address }

output "db_password_secret" { value = google_secret_manager_secret.db_password.secret_id }

output "api_service_account" { value = google_service_account.api.email }

output "artifact_registry" {
  value = "${var.region}-docker.pkg.dev/${var.project}/${google_artifact_registry_repository.apps.repository_id}"
}

output "cloud_run_url" {
  value = var.create_cloud_run && var.image != "" ? google_cloud_run_v2_service.api[0].uri : null
}

output "gke_get_credentials" {
  value = var.create_gke ? "gcloud container clusters get-credentials two-tier --region ${var.region} --project ${var.project}" : null
}
