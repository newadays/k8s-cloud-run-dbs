# Tier 2: Cloud SQL for PostgreSQL, private IP only, password generated here and
# stored in Secret Manager so it never passes through a variable or a tfvars file.
# (It is still in Terraform state; see Module 1b Part D on protecting state.)

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "db_password" {
  secret_id  = "db-password"
  labels     = local.labels
  depends_on = [google_project_service.apis]
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db.result
}

resource "google_sql_database_instance" "db" {
  name                = "two-tier-db"
  database_version    = "POSTGRES_16"
  region              = var.region
  deletion_protection = local.is_prod
  depends_on          = [google_service_networking_connection.psa]

  settings {
    tier              = var.db_tier
    availability_type = local.is_prod ? "REGIONAL" : "ZONAL"
    disk_autoresize   = true
    user_labels       = local.labels

    ip_configuration {
      ipv4_enabled    = false # no public IP, ever
      private_network = google_compute_network.vpc.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
      backup_retention_settings { retained_backups = local.is_prod ? 14 : 3 }
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }
    database_flags {
      name  = "log_min_duration_statement"
      value = "1000"
    }

    maintenance_window {
      day  = 7
      hour = 4
    }
  }
}

resource "google_sql_database" "app" {
  name     = "app"
  instance = google_sql_database_instance.db.name
}

resource "google_sql_user" "app" {
  name     = "app"
  instance = google_sql_database_instance.db.name
  password = random_password.db.result
}
